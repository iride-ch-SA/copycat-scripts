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
#  driver - so it is installed when it matches and never counted
#  as covering anything. pnputil stages it and answers "driver
#  package updated on device, 0 added", which reads like success
#  while the device stays at problem 28.
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
#  4 is asked BEFORE 2 and 3, and must stay that way. A restart
#  pending says the run is not over: the devices still unclaimed
#  cannot be counted while a package waits for a restart to take
#  charge, and a package that could not be installed does not
#  change that. What failed is named on the console either way.
#
#  SEVERAL PASSES, not one. A bus - SerialIO, SMBus, the audio
#  controller, the CNVi radio - enumerates its children only once
#  its own driver runs, so devices appear during the run that
#  were not there when it started, and a scan that looks once
#  never sees them. So the scan repeats - enumerate, match,
#  install what has not been tried yet - until a pass finds
#  nothing new to install, with a ceiling of -Rounds passes. It
#  costs one enumeration per pass: the .inf files are read once
#  and kept. Every pass after the first waits -SettleSeconds
#  before looking, because Plug and Play does not bring the
#  children of a driver up while pnputil is still speaking.
#
#  A restart is a different matter and keeps its own path: what
#  needs one cannot be seen in this run at all, so pnputil
#  asking for it ends the passes and hands the machine to
#  cats-resume, which restarts and runs this recipe again.
#
#  pnputil /add-driver ... /install needs an elevated prompt and
#  Windows 10 1607 or later.
# ============================================================

[CmdletBinding()]
param(
	[string]$Path = 'C:\Admin\Drivers',
	[switch]$Check,
	# Four is not a measurement, it is a ceiling: the passes stop by themselves as soon as one
	# finds nothing new to install, and this only bounds a machine that would never settle
	[int]$Rounds = 4,
	# Plug and Play does not bring a device up while pnputil is still speaking: the children of a
	# driver that has just taken charge appear a moment later, and a pass that asks immediately asks
	# too early. Five seconds is a guess on the generous side of what costs nothing in a deployment
	[int]$SettleSeconds = 5
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
# 0x800B0101 is CERT_E_EXPIRED: a package Windows will not stage at all, and no run of this
# recipe can change that - the only way in would be to turn the signature enforcement of the
# machine off. Vendor packages carry such files, user interfaces and optional configurations
# rather than drivers, so it is named and stepped over instead of failing the run. Every other
# trust error stays a failure.
$PNPUTIL_RESTART_NEEDED = 3010
$PNPUTIL_NOTHING_ADDED = 259
$CERT_E_EXPIRED = -2146762495

# ---- What does Windows say is broken ----
#
# Asked again at every pass, because the answer changes as drivers take charge.

function Get-NeedyDevices {
	$found = @()
	$off = 0
	$other = 0
	foreach ($device in @(Get-PnpDevice -PresentOnly -ErrorAction Stop | Where-Object { $_.Status -ne 'OK' })) {
		$problem = -1
		try {
			$property = Get-PnpDeviceProperty -InstanceId $device.InstanceId -KeyName 'DEVPKEY_Device_ProblemCode' -ErrorAction Stop
			if ($null -ne $property -and $null -ne $property.Data) { $problem = [int]$property.Data }
		} catch {
			# Older builds do not expose the property; -1 is "not known" and the device is kept
		}
		if ($notADriverProblem -contains $problem) { $off++; continue }
		if ($problem -ge 0 -and -not ($needsDriver -contains $problem)) {
			$other++
			continue
		}
		$name = $device.FriendlyName
		if ([string]::IsNullOrWhiteSpace($name)) { $name = $device.InstanceId }
		$found += [pscustomobject]@{
			Name       = $name
			InstanceId = $device.InstanceId
			Problem    = $problem
			Ids        = Get-DeviceIds $device.InstanceId
		}
	}
	return [pscustomobject]@{ Needy = @($found); OffOrUnplugged = $off; OtherProblem = $other }
}

if (-not (Test-Path -LiteralPath $Path)) {
	Write-Fail "there is no driver library at $Path, so nothing can be matched against the devices of this machine"
	exit 3
}

$architecture = Get-HostArchitecture

$elevated = $null
try {
	$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
	$elevated = (New-Object Security.Principal.WindowsPrincipal $identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch {
	# Not determinable here; pnputil will say so itself if the prompt is not elevated
}
if (-not $Check -and $elevated -eq $false) {
	Write-Fail "this recipe needs an elevated prompt: pnputil writes to the machine driver store"
	exit 2
}

$packages = @(Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '^\.(exe|msi|zip|cab|7z)$' })

$installed = 0
$alreadyThere = 0
$skipped = 0
$failed = 0
$restart = $false
$attempted = @{}
$seen = @{}
$round = 0
$needy = @()
$library = $null

while ($true) {
	$round++
	if ($round -eq 1) {
		Write-Recipe "Looking for devices that are missing a driver"
	} else {
		Write-Recipe "Looking again: pass $round, because a driver in charge can bring devices with it"
		if ($SettleSeconds -gt 0) {
			Write-Plain "waiting $SettleSeconds second(s) first: what the last package brought up is not there the instant pnputil returns"
			Start-Sleep -Seconds $SettleSeconds
		}
	}

	$state = Get-NeedyDevices
	$needy = $state.Needy

	if ($round -eq 1) {
		if ($state.OffOrUnplugged -gt 0) {
			Write-Recipe "$($state.OffOrUnplugged) device(s) are disabled, unplugged or waiting for a restart: not a driver question"
		}
		if ($state.OtherProblem -gt 0) {
			Write-Warn "$($state.OtherProblem) device(s) report a problem a driver does not fix; Device Manager has the detail"
		}
	}

	if ($needy.Count -eq 0) {
		if ($round -eq 1) {
			Write-Recipe "Every device on this machine has a working driver, nothing to install"
		} else {
			Write-Recipe "Nothing is left without a driver"
		}
		break
	}

	$fresh = @($needy | Where-Object { -not $seen.ContainsKey([string]$_.InstanceId) })
	Write-Warn "$($needy.Count) device(s) need a driver:"
	foreach ($device in $needy) {
		$code = if ($device.Problem -ge 0) { "problem $($device.Problem)" } else { "problem code unknown" }
		$news = if ($round -gt 1 -and -not $seen.ContainsKey([string]$device.InstanceId)) { ' - appeared during this run' } else { '' }
		Write-Plain "$($device.Name) - $code$news"
	}
	foreach ($device in $needy) { $seen[[string]$device.InstanceId] = $device.Name }

	if ($round -eq 1) { Write-Recipe "Reading the driver packages under $Path" }
	$library = Get-DriverMatches -Path $Path -Devices $needy -Architecture $architecture

	if ($round -eq 1) {
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
	}

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

	if ($library.Relevant.Count -gt 0) {
		Write-Recipe "$($library.Relevant.Count) driver package(s) fit this machine:"
		foreach ($item in $library.Relevant) {
			Write-Plain "$($item.File)"
			$kind = if ($item.IsExtension) { ' (extension: settings on top of a driver, not a driver)' } else { '' }
			Write-Plain "    for: $($item.Devices -join ', ')$kind"
		}
	} elseif ($round -eq 1) {
		Write-Fail "nothing under $Path fits the device(s) above: the package has to be fetched from the vendor"
		if ($packages.Count -gt 0) {
			Write-Warn "$($packages.Count) vendor package(s) are sitting there unpacked; an operator runs those by hand:"
			foreach ($package in ($packages | Select-Object -First 10)) { Write-Plain $package.FullName }
		}
		exit 3
	}

	if ($Check) {
		Write-Recipe "Check only, nothing was installed"
		if ($library.Uncovered.Count -gt 0) { exit 3 }
		exit 0
	}

	# A package already handed to pnputil in this run is not handed to it again: what it could do,
	# it has done, and a pass that repeated it would never end
	$toInstall = @($library.Relevant | Where-Object { -not $attempted.ContainsKey($_.File) })
	if ($toInstall.Count -eq 0) {
		if ($round -gt 1) { Write-Recipe "Nothing new to install in this pass" }
		break
	}

	if ($round -gt $Rounds) {
		Write-Warn "$Rounds passes were not enough and this one is not taken: run cats install Drivers again"
		break
	}

	foreach ($item in $toInstall) {
		$attempted[$item.File] = $true
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

	# A restart pending means the machine cannot tell us anything more in this run: what is waiting
	# for it is not enumerated yet, so another pass here would look at a stale machine
	if ($restart) { break }
}

if ($seen.Count -gt 0) {
	Write-Recipe "$installed package(s) installed, $alreadyThere already in the driver store, $skipped stepped over, $failed failed, in $round pass(es)"
}

# The loop enumerates at the head of every pass, so what it left in $needy is the state after the
# last installation, not a guess: a package handed to pnputil without a complaint is not a device
# that works, and only the machine can say which it is. $seen holds every device that needed a
# driver at any point of the run, the ones that turned up halfway through included.
$still = @($needy)
if ($seen.Count -gt 0) {
	Write-Recipe "$($seen.Count - $still.Count) of $($seen.Count) device(s) that needed a driver are working now"
}

if ($seen.Count -eq 0) {
	exit 1
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
