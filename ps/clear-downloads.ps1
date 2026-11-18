# ============================================================
#  clear-downloads.ps1
#  Empties the Downloads folder of the account this is run by,
#  and only when that account is the one named by -Account.
#  cats clean itadmin calls it after the new password is set:
#  what an operator downloaded while preparing a machine - the
#  installers, the drivers, the tools - stays in the Downloads
#  folder of itadmin, and the machine leaves with it.
#
#  The folder is the one of the account RUNNING this, read from
#  HKCU, so the two have to be the same: when the prompt is
#  opened by another administrator the folder of itadmin is not
#  the one HKCU points at, and nothing is touched or asked.
#
#    -Account <name>  the only account whose folder is emptied,
#                     compared with %USERNAME%
#    -Mode ask        the folder is emptied after a y/n answer,
#                     and n is the answer to anything but y
#    -Mode yes        the folder is emptied without a question
#
#  The folder is read where Windows keeps it, the Downloads
#  known folder under User Shell Folders, because it can have
#  been moved; %USERPROFILE%\Downloads is the fallback.
#  desktop.ini stays: it is what gives the folder its localised
#  name in Explorer, Download on an Italian machine.
#  Items are deleted, not moved to the recycle bin.
#
#  -Folder points the run at a folder of choice and skips the
#  registry, which is the only way this file can be proved from
#  somewhere that is not Windows.
#
#  Exit codes: 0 the folder was emptied, was already empty, was
#  left as it is by the answer, or is not this account's to
#  empty; 2 something stayed in it, or the folder read is not
#  one this script is willing to empty.
# ============================================================

[CmdletBinding()]
param(
	[string]$Account = 'itadmin',
	[ValidateSet('ask', 'yes')]
	[string]$Mode = 'ask',
	[string]$Folder = ''
)

# An unhandled error is named on the console, with the line it came from, before the
# exit code reaches the caller. Every helper of this repository answers the same way.
trap {
	Write-Host ("ERROR     : clear-downloads failed: " + $_.Exception.Message + " [line " + $_.InvocationInfo.ScriptLineNumber + "]") -ForegroundColor Red
	exit 2
}

function Write-Recipe([string]$text) { Write-Host ("RECIPE    : " + $text) -ForegroundColor Cyan }
function Write-Warn([string]$text)   { Write-Host ("WARNING   : " + $text) -ForegroundColor Yellow }

function Format-Size([int64]$bytes) {
	if ($bytes -ge 1073741824) { return ('{0:N2} GB' -f ($bytes / 1073741824)) }
	if ($bytes -ge 1048576)    { return ('{0:N0} MB' -f ($bytes / 1048576)) }
	return ('{0:N0} KB' -f ($bytes / 1024))
}

function Get-ItemSize($item) {
	if ($item.PSIsContainer) {
		$sum = 0
		foreach ($file in (Get-ChildItem -LiteralPath $item.FullName -Recurse -Force -File -ErrorAction SilentlyContinue)) {
			$sum += $file.Length
		}
		return [int64]$sum
	}
	return [int64]$item.Length
}

# ---- 1. Whose prompt this is ----

# Not a question and not a warning: run by anybody else this is the expected outcome, and
# the operator is only told why the folder was not looked at
if ($env:USERNAME -ne $Account) {
	Write-Recipe ("Downloads folder not touched: this prompt belongs to " + $env:USERNAME + ", not to " + $Account)
	exit 0
}

# ---- 2. Where the folder is ----

if ($Folder -eq '') {
	# {374DE290-123F-4565-9164-39C4925E467B} is the Downloads known folder. The value
	# under User Shell Folders is REG_EXPAND_SZ and is expanded here by hand: the
	# provider hands it back already expanded on some builds and not on others.
	try {
		$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
		$value = (Get-ItemProperty -Path $key -Name '{374DE290-123F-4565-9164-39C4925E467B}' -ErrorAction Stop).'{374DE290-123F-4565-9164-39C4925E467B}'
		if ($value) { $Folder = [Environment]::ExpandEnvironmentVariables([string]$value) }
	} catch {
		# No value is not a failure: the folder has never been moved
	}
	if ($Folder -eq '') { $Folder = Join-Path $env:USERPROFILE 'Downloads' }
}

if (-not (Test-Path -LiteralPath $Folder -PathType Container)) {
	Write-Recipe ("No Downloads folder at " + $Folder + ", nothing to empty")
	exit 0
}

# A known folder can be pointed anywhere, the profile itself or the root of a drive
# included, and emptying it would then take far more than downloads: a folder that is
# one of those is refused
$separator = [IO.Path]::DirectorySeparatorChar
$full = [IO.Path]::GetFullPath($Folder).TrimEnd($separator)
$refused = @($env:USERPROFILE, $env:SystemRoot, $env:SystemDrive, $env:PUBLIC) |
	Where-Object { $_ } |
	ForEach-Object { [IO.Path]::GetFullPath($_ + $separator).TrimEnd($separator) }
if ($full -eq '' -or [IO.Path]::GetPathRoot($full + $separator).TrimEnd($separator) -eq $full -or $refused -contains $full) {
	Write-Warn ("the Downloads folder of " + $Account + " points at " + $Folder + ", which is not emptied by this: nothing was touched")
	exit 2
}

# ---- 3. What is in it ----

$items = @(Get-ChildItem -LiteralPath $full -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'desktop.ini' })
if ($items.Count -eq 0) {
	Write-Recipe ("The Downloads folder of " + $Account + " is already empty")
	exit 0
}

$size = [int64]0
foreach ($item in $items) { $size += (Get-ItemSize $item) }

if ($Mode -eq 'ask') {
	$answer = Read-Host ("Empty the Downloads folder of " + $Account + ", " + $items.Count + " item(s), " + (Format-Size $size) + ", in " + $full + "? [y/N]")
	if ($answer -notmatch '^\s*(y|yes)\s*$') {
		Write-Recipe "The Downloads folder is left as it is"
		exit 0
	}
}

# ---- 4. Emptying it ----

Write-Recipe ("Emptying the Downloads folder of " + $Account + ", " + $items.Count + " item(s), " + (Format-Size $size))
$stuck = 0
foreach ($item in $items) {
	try {
		Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
	} catch {
		# A file still open in a program cannot go, and nothing else here is worth
		# stopping for: the rest is removed and what stayed is counted
		if (Test-Path -LiteralPath $item.FullName) { $stuck++ }
	}
}

if ($stuck -gt 0) {
	Write-Warn ($stuck.ToString() + " item(s) stayed in " + $full + ": they are in use, close the program that holds them and run this again")
	exit 2
}

Write-Recipe ("The Downloads folder of " + $Account + " is empty")
exit 0
