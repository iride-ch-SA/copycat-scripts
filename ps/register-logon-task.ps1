[CmdletBinding()]
param(
	[string]$taskname,
	[string]$command,
	[string]$sid = 'S-1-5-32-545',
	[switch]$elevated,
	[string]$timelimit = 'PT1H',
	[switch]$force,
	[switch]$quiet
)

# An unhandled error is named on the console, with the line it came from, before the
# exit code reaches the caller. Every helper of this repository answers the same way.
trap {
	Write-Host ("ERROR     : register-logon-task failed: " + $_.Exception.Message + " [line " + $_.InvocationInfo.ScriptLineNumber + "]") -ForegroundColor Red
	exit 2
}

# ============================================================
#  register-logon-task.ps1
#  Registers a scheduled task that runs a command at every sign
#  in of every member of a local group, and proves the result by
#  reading the registered task back.
#    -taskname <name>  : the task name, as it appears in taskschd
#    -command <path>   : the batch file or executable it runs
#    -sid <S-1-5-32-x> : the group the task runs for, always by
#                        SID, S-1-5-32-545 (Users) by default
#    -elevated         : the task runs with the highest rights
#                        the account has, instead of the plain
#                        unelevated ones
#    -timelimit <PTnH> : how long the task may run before the
#                        scheduler stops it, ISO 8601, PT1H by
#                        default
#    -force            : register again a task that is already
#                        there exactly as asked
#    -quiet            : only problems are printed
#  The principal is a group and not a user, because a logon task
#  registered the plain way runs for the account that created it
#  and for no one else, and the chain has to resume at the logon
#  of whichever administrator is at the machine.
#  Two ways are tried, in this order, and neither leaves anything
#  to be done by hand:
#    1. Register-ScheduledTask, with a group principal;
#    2. schtasks - the task is created the plain way, its own
#       definition is read back, the principal is rewritten into
#       the group and the logon trigger loses the account it was
#       bound to, and the definition is imported over the task
#       that was just created.
#  The group is named by SID because the builtin groups are
#  translated on a localised Windows: Users is "Utenti".
#  The task runs unelevated, with the rights of whoever signs in,
#  but registering a task for a group needs an elevated prompt.
#  With -elevated it runs elevated instead, which is what a task
#  resuming an installation needs and what a logon script does
#  not: the two are asked for apart on purpose. The run level is
#  part of what is compared when a task is already there, so an
#  unelevated task of the same name is rewritten and not taken
#  for the one that was asked for.
#  A task that is already registered for the same group and runs
#  the same command is NOT registered again: it is reported and
#  left alone, because rewriting it would say nothing and would
#  hide the fact that the machine was already deployed. One that
#  exists and does not match is rewritten, after saying what it
#  was - that is the task a half finished fallback leaves behind.
#  Exit codes: 0 registered and verified, 3 already registered as
#  asked and left untouched, 2 for any error. A code above 1 only
#  reaches a .bat caller if powershell is invoked as
#  -command "& <script> <args>; exit $LASTEXITCODE": without that
#  tail every non zero code arrives as 1.
# ============================================================

function Write-Recipe {
	param([string]$text, [string]$colour = 'Cyan')
	if (-not $quiet) { Write-Host ("RECIPE    : " + $text) -ForegroundColor $colour }
}

function Write-Problem {
	param([string]$label, [string]$text, [string]$colour)
	Write-Host ($label.PadRight(10) + ": " + $text) -ForegroundColor $colour
}

function Resolve-RunLevel {
	# The run level is a word from the ScheduledTasks module -
	# Highest or Limited - and another one in an exported
	# definition - HighestAvailable or LeastPrivilege. Both are
	# brought to the module's two before being compared
	param([string]$level)

	if (-not $level) { return 'Limited' }
	if ($level -match '(?i)^(Highest|HighestAvailable)$') { return 'Highest' }
	return 'Limited'
}

function Resolve-Sid {
	# The principal read back is a name on some builds and a SID on
	# others, so both are turned into a SID before being compared
	param([string]$principal)

	if (-not $principal) { return $null }
	if ($principal -match '^(?i)S(-\d+)+$') { return $principal }
	Try {
		return (New-Object System.Security.Principal.NTAccount($principal)).Translate([System.Security.Principal.SecurityIdentifier]).Value
	} Catch {
		return $null
	}
}

function Resolve-Name {
	# The other way round, for error messages: a SID says nothing to
	# whoever is reading the console
	param([string]$principal)

	Try {
		return (New-Object System.Security.Principal.SecurityIdentifier($principal)).Translate([System.Security.Principal.NTAccount]).Value
	} Catch {
		return $principal
	}
}

function Read-TextFile {
	# What schtasks writes is UTF-16 on some builds and the console
	# code page on others: the bytes say which, so they are read as
	# bytes and decoded here instead of being trusted to a pipe
	param([string]$path)

	Try {
		$bytes = [System.IO.File]::ReadAllBytes($path)
	} Catch {
		return $null
	}

	if ($bytes.Length -eq 0) { return $null }

	$text = $null
	if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
		$text = [System.Text.Encoding]::Unicode.GetString($bytes)
	} elseif ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
		$text = [System.Text.Encoding]::UTF8.GetString($bytes)
	} else {
		$text = [System.Text.Encoding]::Default.GetString($bytes)
	}

	return $text.TrimStart([char]0xFEFF)
}

function Get-TempXmlPath {
	return (Join-Path ([System.IO.Path]::GetTempPath()) ("logon-task-" + [guid]::NewGuid().ToString("N") + ".xml"))
}

function Export-TaskXml {
	# The definition of the task as schtasks itself wrote it, sent to a
	# file rather than to a pipe so that its encoding survives
	param([string]$name)

	$path = Get-TempXmlPath
	Try {
		$process = Start-Process -FilePath "schtasks.exe" -ArgumentList ('/query /tn "' + $name + '" /xml ONE') -RedirectStandardOutput $path -NoNewWindow -Wait -PassThru
	} Catch {
		Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
		return $null
	}

	$text = $null
	if ($process.ExitCode -eq 0) { $text = Read-TextFile $path }
	Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
	return $text
}

function Register-WithModule {
	param([string]$name, [string]$path, [string]$account, [string]$level, [timespan]$limit)

	Try {
		$action = New-ScheduledTaskAction -Execute $path
		$trigger = New-ScheduledTaskTrigger -AtLogOn
		$principal = New-ScheduledTaskPrincipal -GroupId $account -RunLevel $level
		# A sign-in script a laptop skips on battery is a sign-in script that
		# runs at the desk and nowhere else: the two battery defaults of
		# New-ScheduledTaskSettingsSet are turned off here on purpose
		$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit $limit
		Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force -ErrorAction Stop | Out-Null
	} Catch {
		Write-Problem "WARNING" ("Register-ScheduledTask did not register the task: " + $_.Exception.Message) "Yellow"
		return $false
	}

	return $true
}

function Register-WithSchtasks {
	# The second way, and the reason nothing is left in taskschd.msc: the
	# task is created for whoever is running this, then handed to the group
	# by rewriting the definition schtasks exported and importing it back
	param([string]$name, [string]$path, [string]$group, [string]$level, [string]$limit)

	# The two words the task schema uses for what the module calls
	# Highest and Limited
	$runlevel = 'LeastPrivilege'
	if ($level -eq 'Highest') { $runlevel = 'HighestAvailable' }

	& schtasks.exe /create /tn $name /tr $path /sc onlogon /f | Out-Null
	if ($LASTEXITCODE -ne 0) {
		Write-Problem "WARNING" ("schtasks did not create the task '" + $name + "'") "Yellow"
		return $false
	}

	$text = Export-TaskXml $name
	if (-not $text) {
		Write-Problem "WARNING" ("the definition of '" + $name + "' could not be exported, so it cannot be handed to the group") "Yellow"
		return $false
	}

	$principal = [regex]::Match($text, '(?s)<Principal\b[^>]*>.*?</Principal>')
	if (-not $principal.Success) {
		Write-Problem "WARNING" "the exported definition has no principal to rewrite" "Yellow"
		return $false
	}

	$id = 'Author'
	$attribute = [regex]::Match($principal.Value, 'id="([^"]*)"')
	if ($attribute.Success) { $id = $attribute.Groups[1].Value }

	# GroupId before RunLevel: the task schema wants them in that order,
	# and LeastPrivilege is the unelevated run of -RunLevel Limited
	$rewritten = '<Principal id="' + $id + '">' + "`r`n      <GroupId>" + $group + "</GroupId>`r`n      <RunLevel>" + $runlevel + "</RunLevel>`r`n    </Principal>"
	$text = $text.Replace($principal.Value, $rewritten)

	# A logon trigger carries the account it was created for. Left there,
	# the task would belong to the group and still start for one user only
	$trigger = [regex]::Match($text, '(?s)<LogonTrigger\b[^>]*>.*?</LogonTrigger>')
	if ($trigger.Success) {
		$text = $text.Replace($trigger.Value, [regex]::Replace($trigger.Value, '(?s)\s*<UserId>.*?</UserId>', ''))
	}

	# schtasks leaves the two battery defaults on, and the module path turns
	# them off: a sign-in script a laptop skips when unplugged is a sign-in
	# script that runs at the desk and nowhere else. The execution limit is
	# brought to the asked one too, in place of the three days schtasks
	# writes. All three are always in an exported definition
	$text = [regex]::Replace($text, '<DisallowStartIfOnBatteries>.*?</DisallowStartIfOnBatteries>', '<DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>')
	$text = [regex]::Replace($text, '<StopIfGoingOnBatteries>.*?</StopIfGoingOnBatteries>', '<StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>')
	$text = [regex]::Replace($text, '<ExecutionTimeLimit>.*?</ExecutionTimeLimit>', ('<ExecutionTimeLimit>' + $limit + '</ExecutionTimeLimit>'))

	# Written back as UTF-16, which is what an exported definition declares
	# and what schtasks /xml reads without complaining about the encoding
	$declaration = [regex]::Match($text, '^<\?xml[^>]*\?>')
	if ($declaration.Success) {
		$text = $text.Replace($declaration.Value, '<?xml version="1.0" encoding="UTF-16"?>')
	} else {
		$text = '<?xml version="1.0" encoding="UTF-16"?>' + "`r`n" + $text
	}

	$file = Get-TempXmlPath
	$code = 1
	Try {
		[System.IO.File]::WriteAllText($file, $text, (New-Object System.Text.UnicodeEncoding($false, $true)))
		& schtasks.exe /create /tn $name /xml $file /f | Out-Null
		$code = $LASTEXITCODE
	} Catch {
		Write-Problem "WARNING" ("the rewritten definition could not be imported: " + $_.Exception.Message) "Yellow"
		Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
		return $false
	}

	Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue

	if ($code -ne 0) {
		Write-Problem "WARNING" ("schtasks refused the definition naming " + $group + " as the principal") "Yellow"
		return $false
	}

	return $true
}

function Format-Command {
	# The path a task runs comes back quoted from one tool and bare from the
	# other, so both are brought to the same shape before being compared
	param([string]$text)

	if (-not $text) { return '' }
	return $text.Trim().Trim('"').Trim()
}

function Get-RegisteredTask {
	# Read the task back, with either tool this machine happens to have, and
	# say who it runs for - as a SID - and what it runs. Asked twice: once
	# before registering, because a task already there is not to be written
	# over in silence, and once after, because registering is not the same
	# as being registered the way it was asked. $null means it is not there
	param([string]$name)

	$principal = $null
	$run = $null
	$level = $null

	if (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue) {
		# The name can exist in more than one folder of the scheduler, and a
		# Principal read off an array is an error, not a principal
		$task = @(Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue)[0]
		if (-not $task) { return $null }
		$principal = $task.Principal.GroupId
		if (-not $principal) { $principal = $task.Principal.UserId }
		$level = $task.Principal.RunLevel
		$action = @($task.Actions)[0]
		if ($action) { $run = $action.Execute }
	} else {
		$text = Export-TaskXml $name
		if (-not $text) { return $null }

		$block = [regex]::Match($text, '(?s)<Principal\b[^>]*>.*?</Principal>')
		if ($block.Success) {
			$group = [regex]::Match($block.Value, '(?s)<GroupId>(.*?)</GroupId>')
			$user = [regex]::Match($block.Value, '(?s)<UserId>(.*?)</UserId>')
			if ($group.Success) {
				$principal = $group.Groups[1].Value.Trim()
			} elseif ($user.Success) {
				$principal = $user.Groups[1].Value.Trim()
			}

			$run_level = [regex]::Match($block.Value, '(?s)<RunLevel>(.*?)</RunLevel>')
			if ($run_level.Success) { $level = $run_level.Groups[1].Value.Trim() }
		}

		$exec = [regex]::Match($text, '(?s)<Exec\b[^>]*>.*?<Command>(.*?)</Command>')
		if ($exec.Success) { $run = $exec.Groups[1].Value }
	}

	$state = New-Object PSObject
	$state | Add-Member NoteProperty Sid (Resolve-Sid $principal)
	$state | Add-Member NoteProperty Command (Format-Command $run)
	$state | Add-Member NoteProperty RunLevel (Resolve-RunLevel ([string]$level))
	return $state
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

$span = $null
Try {
	$span = [System.Xml.XmlConvert]::ToTimeSpan($timelimit)
} Catch {
	Write-Problem "ERROR" ("-timelimit " + $timelimit + " is not an ISO 8601 duration: PT1H, PT4H, PT30M") "Red"
	exit 2
}

$level = 'Limited'
if ($elevated) { $level = 'Highest' }

$account = $null
Try {
	$account = (New-Object System.Security.Principal.SecurityIdentifier($sid)).Translate([System.Security.Principal.NTAccount]).Value
} Catch {
	Write-Problem "ERROR" ("the SID " + $sid + " does not resolve to a group on this machine") "Red"
	exit 2
}

# What is already on this machine is read before anything is written: a
# deploy run twice has to say so, not lay the same task over itself and
# report it as new. A task that does not match is another matter - that
# is what a fallback that failed halfway leaves behind - and it is said
# out loud and then rewritten
$existing = Get-RegisteredTask $taskname
if ($existing) {
	$wanted = Format-Command $command
	$same = ($existing.Sid -eq $sid) -and ($existing.Command -ieq $wanted) -and ($existing.RunLevel -eq $level)

	if ($same -and -not $force) {
		Write-Recipe ("'" + $taskname + "' is already registered for " + $account + " and runs " + $existing.Command + ": nothing was changed") "Green"
		exit 3
	}

	if ($same) {
		Write-Recipe ("'" + $taskname + "' is already registered as asked, and -force was given: registering it again") "Yellow"
	} else {
		$who = 'a principal that cannot be read'
		if ($existing.Sid) { $who = Resolve-Name $existing.Sid }
		$what = 'a command that cannot be read'
		if ($existing.Command) { $what = $existing.Command }
		Write-Problem "WARNING" ("'" + $taskname + "' is already on this machine, runs " + $what + " for " + $who + " at run level " + $existing.RunLevel + ", and does not match what was asked: it is registered again") "Yellow"
	}
}

$registered = $false

if (Get-Command Register-ScheduledTask -ErrorAction SilentlyContinue) {
	$registered = Register-WithModule $taskname $command $account $level $span
} else {
	Write-Problem "WARNING" "the ScheduledTasks module is not available on this machine" "Yellow"
}

if (-not $registered) {
	Write-Recipe ("Registering '" + $taskname + "' with schtasks instead, and handing it to " + $account) "Yellow"
	$registered = Register-WithSchtasks $taskname $command $sid $level $timelimit
}

if (-not $registered) {
	Write-Problem "ERROR" ("the task '" + $taskname + "' could not be registered for " + $account + ". Registering a task for a group needs an elevated prompt: the lines above say what failed") "Red"
	exit 2
}

$state = Get-RegisteredTask $taskname
$read = $null
if ($state) { $read = $state.Sid }
if (-not $read) {
	Write-Problem "ERROR" ("the task '" + $taskname + "' was registered without error but cannot be read back, so nothing proves it exists") "Red"
	exit 2
}

if ($read -ne $sid) {
	Write-Problem "ERROR" ("the task '" + $taskname + "' runs for " + (Resolve-Name $read) + " and not for " + $account + ": it would not start for the other users of this machine") "Red"
	exit 2
}

if ($state.RunLevel -ne $level) {
	Write-Problem "ERROR" ("the task '" + $taskname + "' runs at run level " + $state.RunLevel + " and not " + $level + ": what it runs would not have the rights it needs") "Red"
	exit 2
}

$how = 'unelevated'
if ($level -eq 'Highest') { $how = 'elevated' }
Write-Recipe ("'" + $taskname + "' runs " + $command + " " + $how + " at every sign-in of " + $account) "Green"
exit 0
