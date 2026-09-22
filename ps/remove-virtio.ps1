# ============================================================
#  remove-virtio.ps1
#  Takes the VirtIO driver packages of the Proxmox image out of
#  the machine driver store. The guest software is a winget
#  package and cats clean Wildcat virtio uninstalls it; the
#  driver packages are a different thing and stay behind it -
#  netkvm, viostor, vioscsi, balloon, vioserial, and the rest -
#  because uninstalling a program does not remove what pnputil
#  staged. On real hardware nothing binds them and they are
#  inert, but "the guest drivers are out" is either true or it
#  is not.
#
#  What is removed, and what is not:
#    - only packages whose provider is Red Hat, which is what
#      the virtio-win packages declare, and only third party
#      ones - Get-WindowsDriver -Online without -All never
#      returns an inbox driver, so nothing of Windows itself is
#      ever a candidate;
#    - never a package a present device is actually using. The
#      inf each device runs on is read from the device, and a
#      package on that list is named and left alone. A machine
#      that still boots or talks through VirtIO - one imaged and
#      not yet moved to real hardware - therefore keeps what it
#      is standing on;
#    - never with /force. pnputil refuses to remove a package in
#      use, and that refusal is a guard, not an obstacle to work
#      around.
#
#  Parameters:
#    -Check      report what would be removed, remove nothing
#    -Provider   the provider to match, 'red hat' by default, as
#                a regular expression
#
#  Exit codes: 0 at least one package was removed, 1 there was
#  nothing of that provider to remove, 2 the driver store could
#  not be read or a removal failed for a reason somebody has to
#  read, 3 every candidate was in use and none could be removed.
#
#  Rolling back: the packages come from the virtio-win iso and
#  are re-staged with pnputil /add-driver, or the machine is
#  imaged again. Nothing here touches a device, only the store.
#
#  Needs an elevated prompt.
# ============================================================

[CmdletBinding()]
param(
	[switch]$Check,
	[string]$Provider = 'red\s*hat'
)

$ErrorActionPreference = 'Stop'

function Write-Recipe([string]$text) { Write-Host ("RECIPE    : " + $text) -ForegroundColor Cyan }
function Write-Warn([string]$text)   { Write-Host ("WARNING   : " + $text) -ForegroundColor Yellow }
function Write-Fail([string]$text)   { Write-Host ("ERROR     : " + $text) -ForegroundColor Red }
function Write-Plain([string]$text)  { Write-Host ("            " + $text) }

trap {
	Write-Fail "remove-virtio failed: $($_.Exception.Message) [line $($_.InvocationInfo.ScriptLineNumber)]"
	exit 2
}

# ---- 1. What is in the store, and from whom ----

$drivers = @()
try {
	# Without -All this is the third party store alone: an inbox driver is never a candidate.
	# ProviderName is a property and not a line of console output, so this does not depend on the
	# language of the machine - pnputil /enum-drivers prints "Nome fornitore" on an Italian one.
	$drivers = @(Get-WindowsDriver -Online -ErrorAction Stop)
} catch {
	Write-Fail "the driver store could not be read: $($_.Exception.Message)"
	Write-Plain "Get-WindowsDriver comes from the DISM module and wants an elevated prompt"
	exit 2
}

$candidates = @($drivers | Where-Object { $_.ProviderName -match $Provider })
if ($candidates.Count -eq 0) {
	Write-Recipe "No driver package of provider /$Provider/ is in the store, nothing to remove"
	exit 1
}

Write-Warn "$($candidates.Count) driver package(s) of provider /$Provider/ are in the store:"
foreach ($item in $candidates) {
	Write-Plain "$($item.Driver) - $($item.ClassName) - $($item.OriginalFileName | Split-Path -Leaf) - $($item.ProviderName) $($item.Version)"
}

# ---- 2. Which of them a device is actually running on ----

$inUse = @{}
try {
	foreach ($device in @(Get-PnpDevice -PresentOnly -ErrorAction Stop)) {
		try {
			$property = Get-PnpDeviceProperty -InstanceId $device.InstanceId -KeyName 'DEVPKEY_Device_DriverInfPath' -ErrorAction Stop
			if ($null -ne $property -and $null -ne $property.Data) {
				$name = $device.FriendlyName
				if ([string]::IsNullOrWhiteSpace($name)) { $name = $device.InstanceId }
				$inUse[([string]$property.Data).Trim().ToLowerInvariant()] = $name
			}
		} catch {
			# A device that does not say which inf it runs on protects nothing and blocks nothing
		}
	}
} catch {
	# Without the device list the only guard left is pnputil's own refusal, which is the real one
	Write-Warn "the devices could not be enumerated ($($_.Exception.Message)); pnputil's own refusal is the remaining guard"
}

$removable = @()
foreach ($item in $candidates) {
	$published = ([string]$item.Driver).Trim().ToLowerInvariant()
	if ($inUse.ContainsKey($published)) {
		Write-Recipe "$($item.Driver) is left alone: $($inUse[$published]) is running on it"
		continue
	}
	if ($item.BootCritical) {
		Write-Recipe "$($item.Driver) is left alone: it is marked boot critical"
		continue
	}
	$removable += $item
}

if ($removable.Count -eq 0) {
	Write-Warn "every VirtIO package in the store is in use by a device of this machine: nothing was removed"
	Write-Plain "that is the expected answer on a machine still running on the Proxmox image"
	exit 3
}

if ($Check) {
	Write-Recipe "$($removable.Count) package(s) would be removed; check only, nothing was done"
	exit 0
}

# ---- 3. Out of the store ----

$removed = 0
$refused = 0
foreach ($item in $removable) {
	Write-Recipe "Removing $($item.Driver) ($($item.ProviderName), $($item.ClassName))"
	# No /force: a package pnputil refuses to remove is one something is still standing on, and
	# that refusal is the last guard between a deployment and a machine that does not boot
	$output = & pnputil.exe /delete-driver $item.Driver 2>&1
	$code = $LASTEXITCODE
	foreach ($line in @($output)) { Write-Plain ([string]$line) }
	if ($code -eq 0) {
		$removed++
	} else {
		Write-Warn "pnputil returned $code for $($item.Driver), so it is still in the store"
		$refused++
	}
}

Write-Recipe "$removed package(s) removed, $refused left in the store"

if ($removed -eq 0) { exit 3 }
exit 0
