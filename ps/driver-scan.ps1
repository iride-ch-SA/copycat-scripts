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
#  Parameters:
#    -Path <folder>  the driver library, C:\Admin\Drivers by
#                    default. The same folder the HPSA9 and
#                    Nvidia recipes download into
#    -Check          report only, install nothing
#
#  Exit codes: 0 a driver was installed (or, with -Check, a
#  relevant one is available), 1 every device already has a
#  working driver so there is nothing to do, 2 something failed
#  and the reason is on the lines above, 3 devices need a driver
#  and the library has nothing that fits them - that is the case
#  where an operator has to go and fetch the package.
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

$idPattern = '(?i)\b(?:PCI|USB|USBPRINT|HID|ACPI|HDAUDIO|INTELAUDIO|SWC|SW|ROOT|SD|MMC|SCSI|IDE|UMB|BTH|BTHENUM|BTHLE|MONITOR|DISPLAY|PCMCIA|WSDPRINT|NET|VEN|WPDBUSENUM|UEFI)\\[A-Z0-9_&.\-+{}]{4,}'

function Get-DeviceIds([string]$instanceId) {
	$ids = @()
	foreach ($key in @('DEVPKEY_Device_HardwareIds', 'DEVPKEY_Device_CompatibleIds')) {
		try {
			$property = Get-PnpDeviceProperty -InstanceId $instanceId -KeyName $key -ErrorAction Stop
			if ($null -ne $property -and $null -ne $property.Data) { $ids += @($property.Data) }
		} catch {
			# A device may carry neither list; that is not a failure of the scan
		}
	}
	return @($ids | Where-Object { $_ } | ForEach-Object { $_.ToString().Trim().ToUpperInvariant() } | Where-Object { $_.Length -gt 0 } | Select-Object -Unique)
}

function Get-DeviceProblem([string]$instanceId) {
	try {
		$property = Get-PnpDeviceProperty -InstanceId $instanceId -KeyName 'DEVPKEY_Device_ProblemCode' -ErrorAction Stop
		if ($null -ne $property -and $null -ne $property.Data) { return [int]$property.Data }
	} catch {
		# Older builds do not expose the property; the caller treats -1 as "not known"
	}
	return -1
}

# The two ids match when they are the same id, or when one is the other cut short at a field
# boundary - that is how Windows ranks a driver written for PCI\VEN_8086&DEV_A0F0 against a
# device that enumerates as PCI\VEN_8086&DEV_A0F0&SUBSYS_89C61028&REV_11. The boundary matters:
# a plain StartsWith would let PCI\VEN_8086&DEV_A0F match the device above and it is a
# different part.
function Test-IdMatch([string]$deviceId, [string]$infId) {
	if ($infId.Length -lt 8 -or $deviceId.Length -lt 8) { return $false }
	if ($deviceId -eq $infId) { return $true }
	if ($deviceId.StartsWith($infId) -and $deviceId.Substring($infId.Length).StartsWith('&')) { return $true }
	if ($infId.StartsWith($deviceId) -and $infId.Substring($deviceId.Length).StartsWith('&')) { return $true }
	return $false
}

# The hardware ids are pulled out of the whole file rather than parsed section by section. An
# inf is a small file and the ids are written in it literally; a real parser would have to
# follow [Manufacturer] into its model sections, honour the decoration suffixes and resolve
# %strings%, and it would buy nothing here - the question asked is "does this package know
# about this device", not "which install section would Windows pick".
function Get-InfIds([string]$file) {
	try {
		$text = Get-Content -LiteralPath $file -Raw -ErrorAction Stop
	} catch {
		Write-Warn "$file could not be read: $($_.Exception.Message)"
		return @()
	}
	if ([string]::IsNullOrWhiteSpace($text)) { return @() }
	$found = @()
	foreach ($match in [regex]::Matches($text, $idPattern)) {
		$found += $match.Value.Trim().TrimEnd(',', ';', '"').ToUpperInvariant()
	}
	return @($found | Select-Object -Unique)
}

# ---- 1. What does Windows say is broken ----

Write-Recipe "Looking for devices that are missing a driver"

$devices = @(Get-PnpDevice -PresentOnly -ErrorAction Stop | Where-Object { $_.Status -ne 'OK' })

$needy = @()
$otherProblem = 0
$offOrUnplugged = 0
foreach ($device in $devices) {
	$problem = Get-DeviceProblem $device.InstanceId
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

$infFiles = @(Get-ChildItem -LiteralPath $Path -Filter '*.inf' -Recurse -File -ErrorAction SilentlyContinue)
$packages = @(Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '^\.(exe|msi|zip|cab|7z)$' })

if ($infFiles.Count -eq 0) {
	Write-Warn "no .inf file under $Path"
} else {
	Write-Recipe "$($infFiles.Count) .inf file(s) to check"
}

$relevant = @()
foreach ($inf in $infFiles) {
	$infIds = Get-InfIds $inf.FullName
	if ($infIds.Count -eq 0) { continue }
	$matched = @()
	foreach ($device in $needy) {
		foreach ($deviceId in $device.Ids) {
			$hit = $false
			foreach ($infId in $infIds) {
				if (Test-IdMatch $deviceId $infId) { $hit = $true; break }
			}
			if ($hit) { $matched += $device.Name; break }
		}
	}
	if ($matched.Count -gt 0) {
		$relevant += [pscustomobject]@{ File = $inf.FullName; Devices = @($matched | Select-Object -Unique) }
	}
}

if ($relevant.Count -eq 0) {
	Write-Fail "nothing under $Path fits the device(s) above: the package has to be fetched from the vendor"
	if ($packages.Count -gt 0) {
		Write-Warn "$($packages.Count) vendor package(s) are sitting there unpacked; an operator runs those by hand:"
		foreach ($package in ($packages | Select-Object -First 10)) { Write-Plain $package.FullName }
	}
	exit 3
}

Write-Recipe "$($relevant.Count) driver package(s) fit this machine:"
foreach ($item in $relevant) {
	Write-Plain "$($item.File)"
	Write-Plain "    for: $($item.Devices -join ', ')"
}

if ($Check) {
	Write-Recipe "Check only, nothing was installed"
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
$failed = 0
$restart = $false

foreach ($item in $relevant) {
	Write-Recipe "Installing $($item.File)"
	$output = & pnputil.exe /add-driver "$($item.File)" /install 2>&1
	$code = $LASTEXITCODE
	foreach ($line in @($output)) { Write-Plain ([string]$line) }
	switch ($code) {
		0     { $installed++ }
		3010  { $installed++; $restart = $true }
		259   { Write-Warn "the package was added to the driver store but matched no device on this machine" }
		default {
			Write-Fail "pnputil returned $code for $($item.File)"
			$failed++
		}
	}
}

# Windows may have picked up a staged driver for a device other than the one it was matched
# against, so the count that means something is the one taken after the fact, not before
$still = 0
try {
	foreach ($device in $needy) {
		$after = Get-PnpDevice -InstanceId $device.InstanceId -ErrorAction SilentlyContinue
		if ($null -ne $after -and $after.Status -ne 'OK') { $still++ }
	}
	Write-Recipe "$($needy.Count - $still) of $($needy.Count) device(s) are working now"
} catch {
	Write-Warn "the device state could not be read back: $($_.Exception.Message)"
}

if ($restart) { Write-Warn "a restart is needed before the new driver is fully in charge" }

if ($failed -gt 0) {
	Write-Fail "$failed driver package(s) failed to install"
	exit 2
}
if ($installed -eq 0) {
	Write-Warn "nothing was installed: the relevant packages were staged but no device took them"
	exit 3
}

Write-Recipe "$installed driver package(s) installed"
exit 0
