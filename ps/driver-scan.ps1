# ============================================================
#  driver-scan.ps1
#  Answers two questions about the machine it runs on, in this
#  order, and acts on the answers:
#    1. does any device still need a driver? Windows says so
#       itself - a device with a problem code is a device whose
#       driver is missing, wrong or not starting - so nothing is
#       guessed from the hardware inventory
#    2. is there anything in the local driver library that fits
#       *those* devices? Every .inf under the library folder is
#       read, the hardware ids it claims are pulled out of it,
#       and an inf counts as relevant only when one of those ids
#       matches an id of a device that needs one
#  What is relevant is then handed to pnputil, which stages it
#  and installs it on the matching device. Nothing else in the
#  library is installed: a driver package that fits no device of
#  this machine has no business in its driver store.
#
#  The matching itself lives in ps\lib-driver-ids.ps1, shared
#  with asus-driver-fetch.ps1: the fetch has to know what this
#  scan will consider unclaimed, or it stops with the catalogue
#  still holding the one package the machine needed.
#
#  An EXTENSION .inf claims a device without being able to serve
#  it - it adds settings on top of the package that installs the
#  driver - so it is installed when it matches but never counted
#  as covering anything. Measured 2026-09-22: HdBusExt.inf of the
#  Intel graphics package claims PCI\VEN_8086&DEV_51CA, the
#  multimedia audio controller of a NUC15CRBC5, and was the only
#  thing in the library claiming it. pnputil staged it, said
#  "driver package updated on device, 0 added", and the device
#  stayed at problem 28 while the fetch went home satisfied.
#
#  Parameters:
#    -Path <folder>  the driver library, C:\Admin\Drivers by
#                    default. The same folder the HPSA9 and
#                    Nvidia recipes download into
#    -Check          report only, install nothing
#
#  Exit codes: 0 a driver was installed and every device that
#  needed one works now - with -Check, every device that needs
#  one has a package here that claims it, 1 every device already
#  has a working driver so there is nothing to do, 2 a package
#  failed to install for a reason somebody has to read, 3 a
#  device is still without a driver and the library has nothing
#  that fits it - that is the case where the package has to be
#  fetched, and -Check answers it without installing anything,
#  4 a driver was installed and pnputil asked for a restart
#  before it is fully in charge.
#
#  4 is asked BEFORE 2 and 3 on purpose. A restart pending is not
#  a verdict on the run, it is a statement that the run is not
#  over: the devices that are still unclaimed cannot be counted
#  while three chipset packages are waiting for a restart to take
#  charge, and a package that could not be installed at all does
#  not change that. Until 2026-09-21 the failure was asked first,
#  and three packages signed with an expired certificate - none
#  of them a driver for any device of the machine - were enough
#  to swallow the restart request and end the chain.
#
#  pnputil /add-driver ... /install needs an elevated prompt and
#  Windows 10 1607 or later.
# ============================================================

[CmdletBinding()]
param(
	[string]$Path = 'C:\Admin\Drivers',
	[switch]$Check
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib-driver-ids.ps1')

function Write-Recipe([string]$text) { Write-Host ("RECIPE    : " + $text) -ForegroundColor Cyan }
function Write-Warn([string]$text)   { Write-Host ("WARNING   : " + $text) -ForegroundColor Yellow }
function Write-Fail([string]$text)   { Write-Host ("ERROR     : " + $text) -ForegroundColor Red }
function Write-Plain([string]$text)  { Write-Host ("            " + $text) }

# An unhandled error here would leave the caller with an exit code and no reason, and this
# recipe is meant to be read by whoever is standing in front of the machine
trap {
	Write-Fail "driver-scan failed: $($_.Exception.Message) [line $($_.InvocationInfo.ScriptLineNumber)]"
	exit 2
}

# ---- Problem codes ----
#
# A device that is not OK is not automatically a device that wants a driver. These are the
# codes a driver package can actually answer: 28 is the plain one, the device with no driver
# installed at all, and it is what an unknown device in Device Manager reports.
$needsDriver = @(1, 3, 10, 12, 14, 18, 19, 28, 31, 35, 37, 38, 39, 41, 48, 52)
# And these are the codes that look like trouble and are not: the device is switched off, or
# unplugged, or waiting for a restart. Installing a driver at them would be noise.
$notADriverProblem = @(21, 22, 24, 25, 26, 27, 29, 45, 47, 54)

# ---- pnputil results ----
#
# 3010 is the restart, 259 is ERROR_NO_MORE_ITEMS - pnputil says it when the call added no new
# package to the store, which on a second pass is every package that was already staged by the
# first one, not "no device wanted it": the same call prints "Driver package updated on device"
# above the line it returns 259 on.
# 0x800B0101 is CERT_E_EXPIRED. It is a package Windows will not stage at all, and no run of
# this recipe can change that: the only way in would be to turn the signature enforcement of
# the machine off, which is not something a posa does. The three packages that met it on
# 2026-09-21 were an Intel DTT user interface marked "DO NOT DISTRIBUTE" and two copies of a
# Wi-Fi special config that disables 802.11be - not a driver for any device on the board - so it
# is named and stepped over instead of failing the run. Every other trust error stays a failure.
$PNPUTIL_RESTART_NEEDED = 3010
$PNPUTIL_NOTHING_ADDED = 259
$CERT_E_EXPIRED = -2146762495

# ---- 1. What does Windows say is broken ----

Write-Recipe "Looking for devices that are missing a driver"

$devices = @(Get-PnpDevice -PresentOnly -ErrorAction Stop | Where-Object { $_.Status -ne 'OK' })

$needy = @()
$otherProblem = 0
$offOrUnplugged = 0
foreach ($device in $devices) {
	$problem = -1
	try {
		$property = Get-PnpDeviceProperty -InstanceId $device.InstanceId -KeyName 'DEVPKEY_Device_ProblemCode' -ErrorAction Stop
		if ($null -ne $property -and $null -ne $property.Data) { $problem = [int]$property.Data }
	} catch {
		# Older builds do not expose the property; -1 is "not known" and the device is kept
	}
	if ($notADriverProblem -contains $problem) { $offOrUnplugged++; continue }
	if ($problem -ge 0 -and -not ($needsDriver -contains $problem)) {
		$otherProblem++
		continue
	}
	$name = $device.FriendlyName
	if ([string]::IsNullOrWhiteSpace($name)) { $name = $device.InstanceId }
	$needy += [pscustomobject]@{
		Name       = $name
		InstanceId = $device.InstanceId
		Problem    = $problem
		Ids        = Get-DeviceIds $device.InstanceId
	}
}

if ($offOrUnplugged -gt 0) {
	Write-Recipe "$offOrUnplugged device(s) are disabled, unplugged or waiting for a restart: not a driver question"
}
if ($otherProblem -gt 0) {
	Write-Warn "$otherProblem device(s) report a problem a driver does not fix; Device Manager has the detail"
}

if ($needy.Count -eq 0) {
	Write-Recipe "Every device on this machine has a working driver, nothing to install"
	exit 1
}

Write-Warn "$($needy.Count) device(s) need a driver:"
foreach ($device in $needy) {
	$code = if ($device.Problem -ge 0) { "problem $($device.Problem)" } else { "problem code unknown" }
	Write-Plain "$($device.Name) - $code"
}

# ---- 2. What does the local library have for them ----

if (-not (Test-Path -LiteralPath $Path)) {
	Write-Fail "there is no driver library at $Path, so nothing can be matched against those devices"
	exit 3
}

Write-Recipe "Reading the driver packages under $Path"

$architecture = Get-HostArchitecture
$library = Get-DriverMatches -Path $Path -Devices $needy -Architecture $architecture

if ($library.InfCount -eq 0) {
	Write-Warn "no .inf file under $Path"
} else {
	Write-Recipe "$($library.InfCount) .inf file(s) to check"
}
if ($library.OtherArchitecture -gt 0) {
	Write-Recipe "$($library.OtherArchitecture) package(s) are for another architecture than $architecture and were left alone"
}
if ($library.Unreadable -gt 0) {
	Write-Warn "$($library.Unreadable) .inf file(s) could not be read"
}

$packages = @(Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '^\.(exe|msi|zip|cab|7z)$' })

# Named before anything is installed, and named again at the end: this is the list that decides
# whether there is still something to fetch, and an operator reading the console has to see it
# whether or not the other devices were served
if ($library.Uncovered.Count -gt 0) {
	Write-Warn "$($library.Uncovered.Count) device(s) have no driver package in $Path that can serve them:"
	foreach ($device in $library.Uncovered) { Write-Plain "$($device.Name) - $($device.InstanceId)" }
	if ($library.ExtensionOnly.Count -gt 0) {
		# The trap this line exists for: something DOES claim the device, and it is a package that
		# cannot give it a driver. Said plainly, or the console reads as a contradiction
		Write-Warn "$($library.ExtensionOnly.Count) device(s) among them are claimed by an extension package alone, which adds settings to a driver and is not one:"
		foreach ($device in $library.ExtensionOnly) { Write-Plain "$($device.Name)" }
	}
	Write-Plain "cats prepare Drivers   asks the vendor catalogue for what is missing"
}

if ($library.Relevant.Count -eq 0) {
	Write-Fail "nothing under $Path fits the device(s) above: the package has to be fetched from the vendor"
	if ($packages.Count -gt 0) {
		Write-Warn "$($packages.Count) vendor package(s) are sitting there unpacked; an operator runs those by hand:"
		foreach ($package in ($packages | Select-Object -First 10)) { Write-Plain $package.FullName }
	}
	exit 3
}

Write-Recipe "$($library.Relevant.Count) driver package(s) fit this machine:"
foreach ($item in $library.Relevant) {
	Write-Plain "$($item.File)"
	$kind = if ($item.IsExtension) { ' (extension: settings on top of a driver, not a driver)' } else { '' }
	Write-Plain "    for: $($item.Devices -join ', ')$kind"
}

if ($Check) {
	Write-Recipe "Check only, nothing was installed"
	if ($library.Uncovered.Count -gt 0) { exit 3 }
	exit 0
}

# ---- 3. Install what fits, and nothing else ----

$elevated = $null
try {
	$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
	$elevated = (New-Object Security.Principal.WindowsPrincipal $identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch {
	# Not determinable here; pnputil will say so itself if the prompt is not elevated
}
if ($elevated -eq $false) {
	Write-Fail "this recipe needs an elevated prompt: pnputil writes to the machine driver store"
	exit 2
}

$installed = 0
$alreadyThere = 0
$skipped = 0
$failed = 0
$restart = $false

foreach ($item in $library.Relevant) {
	Write-Recipe "Installing $($item.File)"
	$output = & pnputil.exe /add-driver "$($item.File)" /install 2>&1
	$code = $LASTEXITCODE
	foreach ($line in @($output)) { Write-Plain ([string]$line) }
	switch ($code) {
		0                        { $installed++ }
		$PNPUTIL_RESTART_NEEDED  { $installed++; $restart = $true }
		$PNPUTIL_NOTHING_ADDED   { $alreadyThere++ }
		$CERT_E_EXPIRED {
			$skipped++
			Write-Warn "this package is signed with a certificate that is no longer valid, so Windows will not stage it; stepped over"
		}
		default {
			Write-Fail "pnputil returned $code for $($item.File)"
			$failed++
		}
	}
}

Write-Recipe "$installed package(s) installed, $alreadyThere already in the driver store, $skipped stepped over, $failed failed"

# Windows may have picked up a staged driver for a device other than the one it was matched
# against, so the count that means something is the one taken after the fact, not before. It is
# also the only honest answer to "did this work": a package handed to pnputil without a
# complaint is not a device that works.
$still = @()
try {
	foreach ($device in $needy) {
		$after = Get-PnpDevice -InstanceId $device.InstanceId -ErrorAction SilentlyContinue
		if ($null -ne $after -and $after.Status -ne 'OK') { $still += $device }
	}
	Write-Recipe "$($needy.Count - $still.Count) of $($needy.Count) device(s) are working now"
} catch {
	Write-Warn "the device state could not be read back: $($_.Exception.Message)"
}

if ($failed -gt 0) {
	Write-Fail "$failed driver package(s) failed to install"
}

# Asked first, and before the failure: see the head of this file
if ($restart) {
	Write-Warn "a restart is needed before the new driver is fully in charge"
	exit 4
}

if ($failed -gt 0) { exit 2 }

if ($still.Count -gt 0) {
	Write-Warn "$($still.Count) device(s) still have no working driver:"
	foreach ($device in $still) { Write-Plain "$($device.Name) - $($device.InstanceId)" }
	Write-Plain "cats prepare Drivers   asks the vendor catalogue for what is missing"
	if ($packages.Count -gt 0) {
		Write-Warn "$($packages.Count) vendor package(s) are sitting there unpacked; an operator runs those by hand:"
		foreach ($package in ($packages | Select-Object -First 10)) { Write-Plain $package.FullName }
	}
	exit 3
}

if ($installed -eq 0) {
	# Every device works and nothing was installed to get there: a second pass after a restart,
	# where the first one had already staged everything. Not a failure and not work.
	Write-Recipe "Nothing was left to install: the packages were already in the driver store"
	exit 1
}

exit 0
