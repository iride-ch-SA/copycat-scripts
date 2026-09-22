# ============================================================
#  retrim-volumes.ps1
#  Runs Optimize-Volume -ReTrim on every volume of this machine
#  that can take it, not on C: alone.
#
#  Why it exists: on a virtual machine a deleted file frees
#  space inside the guest and nothing at all on the host - the
#  blocks stay allocated in the vmdk, the vhdx or the LUN until
#  the guest tells the layer underneath that they are free.
#  ReTrim is that message: it walks the free space of the
#  volume and issues TRIM/UNMAP for it. On a physical SSD it is
#  the same operation, and it gives back to the drive the
#  blocks a delete only marked free. A clean that does not end
#  with a ReTrim leaves a thin disk as large as it was.
#
#  What it takes: every fixed NTFS or ReFS volume with a drive
#  letter and a healthy file system. Not removable drives, not
#  network drives, not CD-ROMs, not RAW volumes - none of them
#  can be retrimmed, and asking costs an error message that
#  says nothing.
#
#  Volumes without a drive letter - the EFI partition, the
#  recovery partition, the Microsoft reserved one - are left
#  out: they are small, they are written once, and they hold
#  what a machine needs to boot. -All takes them in as well.
#
#  A volume can also refuse the operation while being a fine
#  candidate on paper: the storage stack under it may not pass
#  TRIM through - an old virtual controller, a RAID set, a
#  device with no UNMAP support. That is not a fault of this
#  run: it is reported and the next volume is done.
#
#  -List says which volumes would be retrimmed and stops there.
#
#  -TestVolumes is a test hook: it stands in for Get-Volume so
#  that the choice of the volumes, which is the part that can
#  get this wrong, can be exercised from a machine that is not
#  Windows. Objects carrying a TestResult property say what the
#  retrim of that volume is to answer.
#
#  Exit codes: 0 at least one volume was retrimmed (or, with
#  -List, found), 1 there was no volume to retrim, 2 the run
#  cannot do its work - no elevation, or no Optimize-Volume.
# ============================================================

[CmdletBinding()]
param(
	[switch]$List,
	[switch]$All,
	[object[]]$TestVolumes
)

$ErrorActionPreference = 'Continue'

function Write-Recipe([string]$text) { Write-Host ("RECIPE    : " + $text) -ForegroundColor Cyan }
function Write-Warn([string]$text)   { Write-Host ("WARNING   : " + $text) -ForegroundColor Yellow }
function Write-Fail([string]$text)   { Write-Host ("ERROR     : " + $text) -ForegroundColor Red }

# $IsWindows only exists in PowerShell 7: on the 5.1 that the recipes
# call, its absence is itself the answer
$onWindows = $true
if (Test-Path variable:IsWindows) { $onWindows = $IsWindows }

$test = ($PSBoundParameters.Keys -contains 'TestVolumes')

function Format-Size([double]$bytes) {
	if ($bytes -ge 1TB) { return ('{0:N2} TB' -f ($bytes / 1TB)) }
	if ($bytes -ge 1GB) { return ('{0:N2} GB' -f ($bytes / 1GB)) }
	if ($bytes -ge 1MB) { return ('{0:N2} MB' -f ($bytes / 1MB)) }
	return ('{0:N0} bytes' -f $bytes)
}

if (-not $test) {
	if ($onWindows) {
		$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
		if (-not (New-Object Security.Principal.WindowsPrincipal $identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
			Write-Fail "this needs an elevated prompt: a volume is not optimized from a user session"
			exit 2
		}
	}
	if (-not (Get-Command Optimize-Volume -ErrorAction SilentlyContinue)) {
		Write-Fail "Optimize-Volume is not available on this machine: the Storage module is missing, and nothing can be retrimmed"
		exit 2
	}
	if (-not (Get-Command Get-Volume -ErrorAction SilentlyContinue)) {
		Write-Fail "Get-Volume is not available on this machine: the volumes cannot be enumerated"
		exit 2
	}
}

# ---- 1. Every volume of the machine ----

$volumes = @()
if ($test) {
	$volumes = @($TestVolumes)
} else {
	try {
		$volumes = @(Get-Volume -ErrorAction Stop)
	} catch {
		Write-Fail ("the volumes of this machine cannot be read: " + $_.Exception.Message)
		exit 2
	}
}

# ---- 2. The ones a retrim applies to ----

$takeable = @('NTFS', 'ReFS')
$chosen = @()
foreach ($volume in $volumes) {
	# a volume with no letter answers with the NUL character, not with an
	# empty string and not with $null: only a letter counts as a letter
	$letter = ''
	if ([string]$volume.DriveLetter -match '^[A-Za-z]$') { $letter = ([string]$volume.DriveLetter).ToUpper() }
	$name = if ($letter -ne '') { $letter + ':' } elseif ($volume.FileSystemLabel) { '[' + $volume.FileSystemLabel + ']' } else { '[no letter]' }
	$fs = [string]$volume.FileSystemType

	if ([string]$volume.DriveType -ne 'Fixed') {
		Write-Verbose ($name + " left out: it is a " + $volume.DriveType + " drive")
		continue
	}
	if ($takeable -notcontains $fs) {
		# an unformatted or RAW volume has no free space to hand back, and
		# FAT32 and exFAT do not carry the operation
		Write-Verbose ($name + " left out: its file system is " + $(if ($fs -eq '') { 'not readable' } else { $fs }))
		continue
	}
	if ($letter -eq '' -and -not $All) {
		Write-Verbose ($name + " left out: it has no drive letter, and those are the partitions a machine boots from. -All takes them too")
		continue
	}
	# only the states that say the volume is not there are a reason to skip
	# it: Unknown is what a volume on some controllers answers while being
	# perfectly usable, and Optimize-Volume is the one to decide the rest
	if (@('Failed', 'Detached', 'No Media') -contains [string]$volume.OperationalStatus) {
		Write-Warn ($name + " is left out: its operational status is " + $volume.OperationalStatus)
		continue
	}
	# Scan Needed, Spot Fix Needed and Full Repair Needed: the answer to
	# those is chkdsk, and a retrim on a file system asking to be repaired
	# is work done on top of a problem
	if ([string]$volume.HealthStatus -match 'Needed|Failed') {
		Write-Warn ($name + " is left out: the file system reports " + $volume.HealthStatus + ", which chkdsk answers and this does not")
		continue
	}

	$chosen += [pscustomobject]@{
		Name   = $name
		Letter = $letter
		Volume = $volume
	}
}

if ($chosen.Count -eq 0) {
	Write-Warn "there is no volume on this machine a retrim applies to"
	exit 1
}

foreach ($item in $chosen) {
	$volume = $item.Volume
	$size = ''
	if ($volume.Size) {
		$size = ' - ' + (Format-Size $volume.Size)
		if ($null -ne $volume.SizeRemaining) { $size += ', ' + (Format-Size $volume.SizeRemaining) + ' free' }
	}
	$label = ''
	if ($volume.FileSystemLabel) { $label = ' "' + $volume.FileSystemLabel + '"' }
	Write-Recipe ("Volume " + $item.Name + $label + ' ' + $volume.FileSystemType + $size)
}

if ($List) {
	Write-Recipe ("Volumes a retrim would take: " + $chosen.Count)
	exit 0
}

# ---- 3. The retrim itself ----

$done = 0
$refused = 0
foreach ($item in $chosen) {
	Write-Recipe ("Retrimming " + $item.Name + ", which on a large volume takes its time")
	try {
		if ($test) {
			if ($item.Volume.TestResult -eq 'fail') { throw 'the storage stack under this volume does not pass TRIM through' }
		} elseif ($item.Letter -ne '') {
			Optimize-Volume -DriveLetter $item.Letter -ReTrim -ErrorAction Stop
		} else {
			Optimize-Volume -InputObject $item.Volume -ReTrim -ErrorAction Stop
		}
		$done++
		Write-Recipe ($item.Name + " retrimmed: the free space of this volume is now free underneath it as well")
	} catch {
		# a volume whose stack does not carry TRIM answers here, and it is
		# not a fault of this run: the next volume is done
		$refused++
		Write-Warn ($item.Name + " was not retrimmed: " + $_.Exception.Message)
	}
}

# ---- What it came to ----

if ($done -eq 0) {
	Write-Fail "not one volume took the retrim, the lines above say why for each"
	exit 1
}

Write-Recipe ("Volumes retrimmed: " + $done)
if ($refused -gt 0) {
	Write-Warn ($refused.ToString() + " volumes did not take it: their storage stack does not carry TRIM, which no setting of this machine changes")
}
exit 0
