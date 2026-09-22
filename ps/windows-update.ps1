[CmdletBinding()]
param(
	[switch]$check,
	[switch]$quiet
)

# An unhandled error is named on the console, with the line it came from, before the
# exit code reaches the caller. Every helper of this repository answers the same way.
trap {
	Write-Host ("ERROR     : windows-update failed: " + $_.Exception.Message + " [line " + $_.InvocationInfo.ScriptLineNumber + "]") -ForegroundColor Red
	exit 2
}

# ============================================================
#  windows-update.ps1
#  One pass of Windows Update, and an answer the caller can act
#  on: whether a restart has to happen before anything more can
#  be installed.
#    -check   report only, install nothing
#    -quiet   only problems are printed
#  Windows Update does not show everything it has in one go: a
#  cumulative update installs, the machine restarts, and only
#  then does the next one appear. So a single pass cannot say
#  "this machine is up to date" - it can only say "this pass
#  installed something and a restart is pending", and the caller
#  runs it again after the restart until a pass finds nothing.
#  That loop is cats-resume.bat, not this file: here one pass
#  happens and its outcome is reported.
#  Exit codes: 0 nothing left to install and no restart pending,
#  1 a restart is needed before the next pass, 2 the module or
#  the update service could not be used.
#  A code above 1 only reaches a .bat caller if powershell is
#  invoked as -command "& <script> <args>; exit $LASTEXITCODE".
# ============================================================

function Write-Recipe {
	param([string]$text, [string]$colour = 'Cyan')
	if (-not $quiet) { Write-Host ("RECIPE    : " + $text) -ForegroundColor $colour }
}

function Write-Problem {
	param([string]$label, [string]$text, [string]$colour)
	Write-Host ($label.PadRight(10) + ": " + $text) -ForegroundColor $colour
}

function Test-RestartPending {
	# The three places Windows records that it is waiting for a
	# restart. Any one of them is enough, and none of them is the
	# one the others are: Component Based Servicing is set by the
	# servicing stack, the Windows Update key by the update client,
	# PendingFileRenameOperations by anything that could not replace
	# a file that was in use
	$keys = @(
		'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
		'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
	)

	foreach ($key in $keys) {
		if (Test-Path -LiteralPath $key) { return $true }
	}

	Try {
		$session = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction Stop
		if ($session.PendingFileRenameOperations) { return $true }
	} Catch {
		# The value is absent on a machine with nothing pending, and
		# its absence is an error to Get-ItemProperty, not to us
	}

	return $false
}

function Import-UpdateModule {
	# PSWindowsUpdate is what cats update Windows has always used. It
	# is not part of Windows: on a machine that never had it, say so
	# with the line that installs it instead of failing namelessly
	if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
		Try {
			Import-Module PSWindowsUpdate -ErrorAction Stop
			return $true
		} Catch {
			Write-Problem "ERROR" ("PSWindowsUpdate is on this machine but did not load: " + $_.Exception.Message) "Red"
			return $false
		}
	}

	Write-Problem "ERROR" "PSWindowsUpdate is not installed on this machine, so Windows Update cannot be driven from here" "Red"
	Write-Problem "USAGE" "Install-Module PSWindowsUpdate -Force -Scope AllUsers, from an elevated prompt" "Blue"
	return $false
}

if (-not (Import-UpdateModule)) { exit 2 }

# What is on offer before anything is installed: the count is the
# only thing that tells an empty pass from a pass that worked
$offered = @()
Try {
	$offered = @(Get-WindowsUpdate -ErrorAction Stop)
} Catch {
	Write-Problem "ERROR" ("the update service did not answer: " + $_.Exception.Message) "Red"
	exit 2
}

if ($offered.Count -eq 0) {
	if (Test-RestartPending) {
		Write-Recipe "No update is on offer, but this machine is waiting for a restart before it can say more" "Yellow"
		exit 1
	}
	Write-Recipe "This machine has no update left to install" "Green"
	exit 0
}

Write-Recipe ("" + $offered.Count + " update(s) on offer")
foreach ($update in $offered) {
	Write-Recipe ("  " + $update.KB + " " + $update.Title)
}

if ($check) {
	Write-Recipe "-check was given, nothing was installed" "Yellow"
	exit 1
}

# -IgnoreReboot, and not -AutoReboot: the restart is ordered by the
# chain, which writes down what is still to do first. A machine
# restarted from underneath the caller loses the step that comes
# after it
Try {
	Get-WindowsUpdate -Install -AcceptAll -IgnoreReboot -ErrorAction Stop | Out-Null
} Catch {
	Write-Problem "ERROR" ("the installation did not finish: " + $_.Exception.Message) "Red"
	exit 2
}

if (Test-RestartPending) {
	Write-Recipe "The updates are installed and this machine has to restart before the next pass" "Yellow"
	exit 1
}

# Installed with nothing pending: there may still be updates that
# only appear once these are in place, so the caller is told to
# come back rather than being told it is finished
$left = @()
Try {
	$left = @(Get-WindowsUpdate -ErrorAction Stop)
} Catch {
	$left = @()
}

if ($left.Count -gt 0) {
	Write-Recipe ("" + $left.Count + " update(s) appeared after this pass, a restart is asked for before they go in") "Yellow"
	exit 1
}

Write-Recipe "The updates are installed and no restart is pending" "Green"
exit 0
