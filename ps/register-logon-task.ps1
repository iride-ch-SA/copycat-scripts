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
#  operator in taskschd.msc, and the one nobody remembers.
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
	param([string]$name, [string]$path, [string]$account)

	Try {
		$action = New-ScheduledTaskAction -Execute $path
		$trigger = New-ScheduledTaskTrigger -AtLogOn
		$principal = New-ScheduledTaskPrincipal -GroupId $account -RunLevel Limited
		# A sign-in script a laptop skips on battery is a sign-in script that
		# runs at the desk and nowhere else: the two battery defaults of
		# New-ScheduledTaskSettingsSet are turned off here on purpose
		$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 1)
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
	param([string]$name, [string]$path, [string]$group)

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
	$rewritten = '<Principal id="' + $id + '">' + "`r`n      <GroupId>" + $group + "</GroupId>`r`n      <RunLevel>LeastPrivilege</RunLevel>`r`n    </Principal>"
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
	# brought to the hour of the module path too, in place of the three days
	# schtasks writes. All three are always in an exported definition
	$text = [regex]::Replace($text, '<DisallowStartIfOnBatteries>.*?</DisallowStartIfOnBatteries>', '<DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>')
	$text = [regex]::Replace($text, '<StopIfGoingOnBatteries>.*?</StopIfGoingOnBatteries>', '<StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>')
	$text = [regex]::Replace($text, '<ExecutionTimeLimit>.*?</ExecutionTimeLimit>', '<ExecutionTimeLimit>PT1H</ExecutionTimeLimit>')

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

function Get-TaskPrincipalSid {
	# Registering is not the same as being registered the way it was asked:
	# whichever way was taken, the task is read back and its principal
	# returned as a SID, with either tool this machine happens to have
	param([string]$name)

	if (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue) {
		$task = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
		if (-not $task) { return $null }
		$principal = $task.Principal.GroupId
		if (-not $principal) { $principal = $task.Principal.UserId }
		return (Resolve-Sid $principal)
	}

	$text = Export-TaskXml $name
	if (-not $text) { return $null }

	$block = [regex]::Match($text, '(?s)<Principal\b[^>]*>.*?</Principal>')
	if (-not $block.Success) { return $null }

	$group = [regex]::Match($block.Value, '(?s)<GroupId>(.*?)</GroupId>')
	if ($group.Success) { return (Resolve-Sid $group.Groups[1].Value.Trim()) }

	$user = [regex]::Match($block.Value, '(?s)<UserId>(.*?)</UserId>')
	if ($user.Success) { return (Resolve-Sid $user.Groups[1].Value.Trim()) }

	return $null
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

$registered = $false

if (Get-Command Register-ScheduledTask -ErrorAction SilentlyContinue) {
	$registered = Register-WithModule $taskname $command $account
} else {
	Write-Problem "WARNING" "the ScheduledTasks module is not available on this machine" "Yellow"
}

if (-not $registered) {
	Write-Recipe ("Registering '" + $taskname + "' with schtasks instead, and handing it to " + $account) "Yellow"
	$registered = Register-WithSchtasks $taskname $command $sid
}

if (-not $registered) {
	Write-Problem "ERROR" ("the task '" + $taskname + "' could not be registered for " + $account + ". Registering a task for a group needs an elevated prompt: the lines above say what failed") "Red"
	exit 2
}

$read = Get-TaskPrincipalSid $taskname
if (-not $read) {
	Write-Problem "ERROR" ("the task '" + $taskname + "' was registered without error but cannot be read back, so nothing proves it exists") "Red"
	exit 2
}

if ($read -ne $sid) {
	Write-Problem "ERROR" ("the task '" + $taskname + "' runs for " + (Resolve-Name $read) + " and not for " + $account + ": it would not start for the other users of this machine") "Red"
	exit 2
}

Write-Recipe ("'" + $taskname + "' runs " + $command + " at every sign-in of " + $account) "Green"
exit 0
