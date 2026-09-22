# ============================================================
#  clean-temp.ps1
#  Takes the logs and the temporary files off this machine.
#  Written for what comes before a sysprep: an image carries
#  into every deployed copy whatever is left in %TEMP%, in the
#  event logs, in the Windows Update cache and in the crash
#  dumps, and none of it means anything on the machine that
#  receives the image.
#
#  What it clears
#    machine   Windows\Temp, Prefetch, SoftwareDistribution\
#              Download, Windows\Logs, System32\LogFiles,
#              Panther and Sysprep\Panther, Minidump,
#              MEMORY.DMP, the WER queues
#    per user  AppData\Local\Temp, CrashDumps, WER and
#              INetCache of every profile on the machine
#    logs      every event log wevtutil lists
#    bin       the recycle bin of the system drive
#
#  What it does NOT touch, on purpose: C:\Admin, Windows.old,
#  $WinREAgent and the component store - the first is ours, the
#  other three are cleanmgr and DISM work and cats clean disks
#  and cats clean dism-online already do it.
#
#  -List says what would go and how much it is worth, and
#  removes nothing.
#
#  -KeepPath is the one tree that must survive: the shadow copy
#  this very run is reading its .bat files from lives under
#  %TEMP%, so a plain sweep of the folder would delete the code
#  that is running. cats-clean.bat passes CATS_HOME.
#
#  -WindowsDir, -UsersDir and -SystemDrive are there so the
#  sweep can be run against a tree that is not a real Windows
#  installation, which is the only way this file can be proved
#  from somewhere that is not Windows.
#
#  Exit codes: 0 something was cleared (or, with -List, found),
#  1 there was nothing to clear, 2 the run cannot do its work -
#  no elevation, or no folder of the list even exists.
# ============================================================

[CmdletBinding()]
param(
	[switch]$List,
	[string]$KeepPath = '',
	[string]$WindowsDir = '',
	[string]$UsersDir = '',
	[string]$SystemDrive = ''
)

$ErrorActionPreference = 'Continue'

function Write-Recipe([string]$text) { Write-Host ("RECIPE    : " + $text) -ForegroundColor Cyan }
function Write-Warn([string]$text)   { Write-Host ("WARNING   : " + $text) -ForegroundColor Yellow }
function Write-Fail([string]$text)   { Write-Host ("ERROR     : " + $text) -ForegroundColor Red }

# $IsWindows only exists in PowerShell 7: on the 5.1 that the recipes
# call, its absence is itself the answer
$onWindows = $true
if (Test-Path variable:IsWindows) { $onWindows = $IsWindows }

if ($WindowsDir -eq '')  { $WindowsDir  = $env:SystemRoot }
if ($SystemDrive -eq '') { $SystemDrive = $env:SystemDrive }
if ($UsersDir -eq '')    { $UsersDir    = Join-Path $SystemDrive 'Users' }

# The test hooks stand in for a real installation, and with them the
# machine-wide checks - elevation, event logs, recycle bin - are not
# the thing being proved
$live = ($PSBoundParameters.Keys -notcontains 'WindowsDir')

if ($live -and $onWindows) {
	$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
	if (-not (New-Object Security.Principal.WindowsPrincipal $identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
		Write-Fail "this needs an elevated prompt: the temporary folders of the other profiles and the event logs are not readable otherwise"
		exit 2
	}
}

$separator = [IO.Path]::DirectorySeparatorChar
$keepFull = ''
if ($KeepPath -ne '') {
	try { $keepFull = [IO.Path]::GetFullPath($KeepPath.TrimEnd($separator)) } catch { $keepFull = $KeepPath }
}

$script:freed    = 0
$script:kept     = 0
$script:stuck    = 0
$script:visited  = 0

# ---- Helpers ----

function Get-ItemSize($item) {
	if ($item.PSIsContainer) {
		$sum = 0
		foreach ($file in (Get-ChildItem -LiteralPath $item.FullName -Recurse -Force -File -ErrorAction SilentlyContinue)) {
			$sum += $file.Length
		}
		return $sum
	}
	return [int64]$item.Length
}

function Get-PathSize([string]$path) {
	$item = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
	if ($null -eq $item) { return 0 }
	return Get-ItemSize $item
}

function Test-Protected([string]$full) {
	if ($keepFull -eq '') { return $false }
	if ($keepFull -eq $full) { return $true }
	# the shadow copy is a folder under %TEMP%: removing its parent takes
	# it with it, so an ancestor of the kept path is protected too
	return $keepFull.StartsWith($full + $separator, [StringComparison]::OrdinalIgnoreCase)
}

function Remove-OneItem($item) {
	$size = Get-ItemSize $item
	try {
		Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
		$script:freed += $size
		return
	} catch {
		# Two reasons a removal fails here and only one of them is a
		# failure: a file in use cannot go, and that is normal in a Temp
		# folder that belongs to a running session; a path longer than
		# MAX_PATH stops the .NET call and not the shell, so cmd is asked
		# with the \\?\ prefix before the item is given up on
		if ($onWindows) {
			$long = '\\?\' + $item.FullName
			if ($item.PSIsContainer) { & cmd.exe /c rd /s /q "$long" 2>$null }
			else                     { & cmd.exe /c del /f /q /a "$long" 2>$null }
		}
	}
	$left = Get-PathSize $item.FullName
	$script:freed += ($size - $left)
	if ($left -gt 0 -or (Test-Path -LiteralPath $item.FullName)) { $script:stuck++ }
}

function Clear-Contents([string]$path) {
	if ($path -eq '' -or -not (Test-Path -LiteralPath $path)) { return }
	$script:visited++
	foreach ($item in (Get-ChildItem -LiteralPath $path -Force -ErrorAction SilentlyContinue)) {
		if (Test-Protected $item.FullName) { $script:kept++; continue }
		if ($List) { $script:freed += (Get-ItemSize $item); continue }
		Remove-OneItem $item
	}
}

function Clear-OneFile([string]$path) {
	if ($path -eq '' -or -not (Test-Path -LiteralPath $path)) { return }
	$script:visited++
	$item = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
	if ($null -eq $item) { return }
	if ($List) { $script:freed += (Get-ItemSize $item); return }
	Remove-OneItem $item
}

function Format-Size([int64]$bytes) {
	if ($bytes -ge 1073741824) { return ('{0:N2} GB' -f ($bytes / 1073741824)) }
	if ($bytes -ge 1048576)    { return ('{0:N0} MB' -f ($bytes / 1048576)) }
	return ('{0:N0} KB' -f ($bytes / 1024))
}

# ---- 1. The machine wide temporary files ----

if ($List) { Write-Recipe "Listing what a clean would take off this machine, nothing is removed" }
else       { Write-Recipe "Clearing the temporary files of this machine" }

Clear-Contents (Join-Path $WindowsDir 'Temp')
Clear-Contents (Join-Path $WindowsDir 'Prefetch')
Clear-Contents (Join-Path $WindowsDir 'SoftwareDistribution\Download')

# ---- 2. The logs on disk ----

Clear-Contents (Join-Path $WindowsDir 'Logs')
Clear-Contents (Join-Path $WindowsDir 'System32\LogFiles')
Clear-Contents (Join-Path $WindowsDir 'Minidump')
Clear-OneFile  (Join-Path $WindowsDir 'MEMORY.DMP')

# Panther holds the logs and the answer file copies of the setup that
# built this installation, Sysprep\Panther the state of the last
# generalize: neither says anything true about the machine the image
# will be laid on
Clear-Contents (Join-Path $WindowsDir 'Panther')
Clear-Contents (Join-Path $WindowsDir 'System32\Sysprep\Panther')

$programData = $env:ProgramData
if ($programData -eq '' -or $null -eq $programData) { $programData = Join-Path $SystemDrive 'ProgramData' }
foreach ($queue in @('ReportQueue', 'ReportArchive', 'Temp')) {
	Clear-Contents (Join-Path $programData ('Microsoft\Windows\WER\' + $queue))
}

# ---- 3. Every profile on the machine ----

if (Test-Path -LiteralPath $UsersDir) {
	foreach ($profileDir in (Get-ChildItem -LiteralPath $UsersDir -Force -Directory -ErrorAction SilentlyContinue)) {
		# All Users and Default User are junctions to somewhere already in
		# this list: following them would clear the same tree twice and
		# report the bytes twice with it
		if ($profileDir.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
		$local = Join-Path $profileDir.FullName 'AppData\Local'
		Clear-Contents (Join-Path $local 'Temp')
		Clear-Contents (Join-Path $local 'CrashDumps')
		Clear-Contents (Join-Path $local 'Microsoft\Windows\WER')
		Clear-Contents (Join-Path $local 'Microsoft\Windows\INetCache')
	}
}

# ---- 4. The event logs ----

# Only the channels that actually hold something are cleared. wevtutil el lists every
# channel REGISTERED on the machine - about 1200 on a Windows 11 - and clearing an empty
# one succeeds, so a sweep of the whole list reported the same 1202 and 1200 on a machine
# that had just been swept as on one that had never been: the number was a property of
# Windows, not of the state of this machine, and it said nothing. Measured 2026-09-22 on a
# machine in deployment, reported by the operator: same figures on two runs in a row.
# Get-WinEvent -ListLog answers the record count of every channel in ONE call, so the
# channels that hold nothing are skipped: on a machine just installed that is some fifty
# clears instead of twelve hundred, and the figure on the console is the number of logs
# that really had something in them.
$logsCleared = 0
$logsLeft = 0
if ($live -and $onWindows -and (Get-Command wevtutil.exe -ErrorAction SilentlyContinue)) {
	$full = @()
	$counted = $false
	if (Get-Command Get-WinEvent -ErrorAction SilentlyContinue) {
		foreach ($channel in @(Get-WinEvent -ListLog * -ErrorAction SilentlyContinue)) {
			$count = 0
			try { if ($null -ne $channel.RecordCount) { $count = [int]$channel.RecordCount } } catch { }
			if ($count -gt 0) { $full += [string]$channel.LogName }
		}
		$counted = $true
	} else {
		# Without Get-WinEvent there is no record count to read, so the old sweep of the
		# whole list is the only thing left - and the console must not claim a number it
		# did not measure
		$full = @(& wevtutil.exe el 2>$null | Where-Object { $_ -ne '' })
		$counted = $false
	}

	$what = if ($counted) { " event log(s) that hold records" } else { " event log(s), record counts not readable on this build" }
	if ($full.Count -eq 0) {
		Write-Recipe "No event log holds any record, nothing to clear there"
	} elseif ($List) {
		Write-Recipe ("A clean would empty " + $full.Count + $what)
	} else {
		Write-Recipe ("Clearing " + $full.Count + $what)
		foreach ($name in $full) {
			& wevtutil.exe cl "$name" 2>$null
			# analytic and debug logs refuse to be cleared while enabled, and
			# that is not a fault of this run
			if ($LASTEXITCODE -eq 0) { $logsCleared++ } else { $logsLeft++ }
		}
	}
	$script:visited++
}

# ---- 5. The recycle bin ----

if ($live -and $onWindows -and -not $List -and (Get-Command Clear-RecycleBin -ErrorAction SilentlyContinue)) {
	try {
		Clear-RecycleBin -DriveLetter $SystemDrive.TrimEnd(':') -Force -ErrorAction Stop
		Write-Recipe "Recycle bin of the system drive emptied"
	} catch {
		# an empty bin is reported as an error by Clear-RecycleBin itself
		Write-Recipe "Recycle bin of the system drive was already empty"
	}
}

# ---- What it came to ----

if ($script:visited -eq 0) {
	Write-Fail "not one of the folders this clears exists, which is not what a Windows installation looks like: nothing was done"
	exit 2
}

if ($List) {
	Write-Recipe ("A clean would free about " + (Format-Size $script:freed))
	if ($script:kept -gt 0) { Write-Recipe ("Left where it is: " + $keepFull + ", which is the copy this very run is reading its own .bat files from") }
	if ($script:freed -eq 0) { exit 1 }
	exit 0
}

Write-Recipe ("Freed " + (Format-Size $script:freed))
if ($logsCleared -gt 0) { Write-Recipe ("Event logs cleared: " + $logsCleared) }
if ($logsLeft -gt 0)    { Write-Warn ("Event logs that refused to be cleared, analytic and debug ones among them: " + $logsLeft) }
# Named with its path, and said for what it is. It reads as a leftover otherwise, and it is
# the opposite: everything else under the temporary folder went, including the shadow copies
# of the earlier runs, and the one folder that stayed is the one this command is standing on.
# cats-shadow.bat made it when the command started and removes the ones older than a day.
if ($script:kept -gt 0) {
	Write-Recipe ("Left where it is: " + $keepFull)
	Write-Recipe "that folder is the copy this very run is reading its own .bat files from, made when the command started - not a leftover of an earlier one"
}
if ($script:stuck -gt 0) {
	Write-Warn ($script:stuck.ToString() + " items are in use and stay where they are: they belong to a running program, and a clean after a restart takes them")
}
if ($script:freed -eq 0 -and $logsCleared -eq 0) {
	Write-Warn "there was nothing to clear"
	exit 1
}

exit 0
