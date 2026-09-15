param(
	[string]$taskname,
	[string]$command,
	[string]$sid = 'S-1-5-32-545',
	[switch]$quiet
)

# ============================================================
#  register-logon-task.ps1
#  Registers a scheduled task that runs a command at every sign
#  in of every member of a local group, and proves the result by
#  reading the registered task back.
#    -taskname <name>  : the task name, as it appears in taskschd
#    -command <path>   : the batch file or executable it runs
#    -sid <S-1-5-32-x> : the group the task runs for, always by
#                        SID, S-1-5-32-545 (Users) by default
#    -quiet            : only problems are printed
#  The principal is a group and not a user, because a logon task
#  registered the plain way runs for the account that created it
#  and for no one else - the step that used to be left to the
#  operator in taskschd.msc, and the one nobody remembers. The
#  group is named by SID because the builtin groups are
#  translated on a localised Windows: Users is "Utenti".
#  The task runs unelevated, with the rights of whoever signs in.
#  Exit codes: 0 registered and verified, 2 for any error.
# ============================================================

function Write-Recipe {
	param([string]$text, [string]$colour = 'Cyan')
	if (-not $quiet) { Write-Host ("RECIPE    : " + $text) -ForegroundColor $colour }
}

function Write-Problem {
	param([string]$label, [string]$text, [string]$colour)
	Write-Host ($label.PadRight(10) + ": " + $text) -ForegroundColor $colour
}

function Resolve-Sid {
	# The principal read back is a name on some builds and a SID on
	# others, so both are turned into a SID before being compared
	param([string]$principal)

	if ($principal -match '^(?i)S(-\d+)+$') { return $principal }
	Try {
		return (New-Object System.Security.Principal.NTAccount($principal)).Translate([System.Security.Principal.SecurityIdentifier]).Value
	} Catch {
		return $null
	}
}

if (-not $taskname) {
	Write-Problem "ERROR" "-taskname <name> is expected" "Red"
	exit 2
}

if (-not $command) {
	Write-Problem "ERROR" "-command <path> is expected" "Red"
	exit 2
}

if (-not (Test-Path -LiteralPath $command)) {
	Write-Problem "ERROR" ("'" + $command + "' does not exist: a task pointing at a missing file would fail silently at every sign-in") "Red"
	exit 2
}

if ($sid -notmatch '^(?i)S(-\d+)+$') {
	Write-Problem "ERROR" "-sid <S-1-5-32-x> is expected: a builtin group is named by its SID, never by its name" "Red"
	exit 2
}

$account = $null
Try {
	$account = (New-Object System.Security.Principal.SecurityIdentifier($sid)).Translate([System.Security.Principal.NTAccount]).Value
} Catch {
	Write-Problem "ERROR" ("the SID " + $sid + " does not resolve to a group on this machine") "Red"
	exit 2
}

if (-not (Get-Command Register-ScheduledTask -ErrorAction SilentlyContinue)) {
	Write-Problem "ERROR" "the ScheduledTasks module is not available on this machine" "Red"
	exit 2
}

Try {
	$action = New-ScheduledTaskAction -Execute $command
	$trigger = New-ScheduledTaskTrigger -AtLogOn
	$principal = New-ScheduledTaskPrincipal -GroupId $account -RunLevel Limited
	# A sign-in script a laptop skips on battery is a sign-in script that
	# runs at the desk and nowhere else: the two battery defaults of
	# New-ScheduledTaskSettingsSet are turned off here on purpose
	$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 1)
	Register-ScheduledTask -TaskName $taskname -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force -ErrorAction Stop | Out-Null
} Catch {
	Write-Problem "ERROR" ("the task '" + $taskname + "' could not be registered: " + $_.Exception.Message) "Red"
	exit 2
}

# Registering is not the same as being registered the way it was asked:
# the task is read back and its principal compared with the group wanted
$task = Get-ScheduledTask -TaskName $taskname -ErrorAction SilentlyContinue
if (-not $task) {
	Write-Problem "ERROR" ("the task '" + $taskname + "' was registered without error but cannot be read back") "Red"
	exit 2
}

$registered = Resolve-Sid $task.Principal.GroupId
if ($registered -ne $sid) {
	$named = $task.Principal.GroupId
	if (-not $named) { $named = $task.Principal.UserId }
	Write-Problem "ERROR" ("the task '" + $taskname + "' runs for '" + $named + "' and not for " + $account + ": it would not start for the other users of this machine") "Red"
	exit 2
}

Write-Recipe ("'" + $taskname + "' runs " + $command + " at every sign-in of " + $account) "Green"
exit 0
