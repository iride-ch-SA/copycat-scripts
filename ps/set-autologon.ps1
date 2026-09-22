# ============================================================
#  set-autologon.ps1
#  Turns the Windows automatic logon on and off, so that a chain
#  of cats steps that restarts the machine several times carries
#  on without somebody signing in at each restart.
#  Used by cats clean Wildcat, which switches it on as its first
#  step and off as its last, and by cats-resume.bat, which
#  switches it off whenever a chain ends - finished, cancelled
#  or stopped at the ceiling.
#
#  WHOSE PASSWORD, AND WHY IT IS NOT A SECRET HERE. The account
#  is the one the image creates, itadmin, and its password after
#  a deploy is the one written in config\autounattend.xml - in
#  the repository on purpose, because it is a default that every
#  machine starts from and that the operator changes by hand at
#  the end of the deployment. This script READS it from that
#  file rather than carrying a copy: a credential written in two
#  places is a credential that will disagree with itself.
#
#  THE PASSWORD CHANGE IS NOT AUTOMATED, AND MUST NOT BE. It is
#  the last step of the procedure and it belongs to the
#  operator: a generated password set by a chain nobody is
#  watching is a password nobody can read back, and the machine
#  is then lost for good. Nothing here changes any password.
#
#  What the automatic logon is worth knowing about, from the
#  Sysinternals documentation: the password is stored encrypted
#  as an LSA secret and an administrator can retrieve and
#  decrypt it, Autologon does not check the credentials it is
#  given, and Exchange ActiveSync password policies make Windows
#  ignore the whole configuration. So this is best effort by
#  construction: if the logon does not happen the chain is not
#  lost, it waits for an administrator to sign in as it did
#  before this existed.
#
#  Parameters:
#    -Mode on|off|status    what to do; status by default
#    -Username <name>       override the account, itadmin by
#                           default, read from the answer file
#    -Password <secret>     override the password; by default it
#                           is read from the answer file
#    -Answer <path>         the answer file to read them from
#    -AppPath <folder>      where Autologon.exe lives,
#                           C:\Admin\Apps by default
#
#  Exit codes: 0 the automatic logon is on after an -on, or was
#  on and is now off after an -off, or is on for -status; 1
#  there was nothing to do - off already, and -status when it is
#  off; 2 something failed and the reason is on the lines above;
#  3 -on was asked for and Autologon.exe is not on this machine.
#
#  Needs an elevated prompt: it writes under HKLM.
# ============================================================

[CmdletBinding()]
param(
	[ValidateSet('on', 'off', 'status')]
	[string]$Mode = 'status',
	[string]$Username = '',
	[string]$Password = '',
	[string]$Answer = 'C:\Admin\Scripts\config\autounattend.xml',
	[string]$AppPath = 'C:\Admin\Apps'
)

$ErrorActionPreference = 'Stop'

function Write-Recipe([string]$text) { Write-Host ("RECIPE    : " + $text) -ForegroundColor Cyan }
function Write-Warn([string]$text)   { Write-Host ("WARNING   : " + $text) -ForegroundColor Yellow }
function Write-Fail([string]$text)   { Write-Host ("ERROR     : " + $text) -ForegroundColor Red }
function Write-Plain([string]$text)  { Write-Host ("            " + $text) }

trap {
	Write-Fail "set-autologon failed: $($_.Exception.Message) [line $($_.InvocationInfo.ScriptLineNumber)]"
	exit 2
}

$winlogon = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'

function Get-AutologonState {
	$state = [pscustomobject]@{ Enabled = $false; User = ''; Domain = '' }
	try {
		$key = Get-ItemProperty -Path $winlogon -ErrorAction Stop
		if ("$($key.AutoAdminLogon)" -eq '1') { $state.Enabled = $true }
		if ($key.PSObject.Properties.Name -contains 'DefaultUserName') { $state.User = [string]$key.DefaultUserName }
		if ($key.PSObject.Properties.Name -contains 'DefaultDomainName') { $state.Domain = [string]$key.DefaultDomainName }
	} catch {
		# A machine without the value at all is a machine with the automatic logon off
	}
	return $state
}

# The account and its password come from the answer file that created the account, so that the
# two cannot drift apart. Namespaces are dodged with local-name(): the unattend schema declares a
# default namespace and an XPath without it would match nothing at all, silently.
function Get-AnswerAccount([string]$path, [string]$wanted) {
	if (-not (Test-Path -LiteralPath $path)) { return $null }
	try {
		$xml = [xml](Get-Content -LiteralPath $path -Raw -ErrorAction Stop)
	} catch {
		Write-Warn "$path could not be read as XML: $($_.Exception.Message)"
		return $null
	}
	$accounts = @($xml.SelectNodes("//*[local-name()='LocalAccount']"))
	foreach ($account in $accounts) {
		$name = $account.SelectSingleNode("*[local-name()='Name']")
		if ($null -eq $name) { continue }
		if ($wanted -and ([string]$name.InnerText).Trim() -ne $wanted) { continue }
		$value = $account.SelectSingleNode("*[local-name()='Password']/*[local-name()='Value']")
		if ($null -eq $value) { continue }
		return [pscustomobject]@{ Name = ([string]$name.InnerText).Trim(); Password = [string]$value.InnerText }
	}
	return $null
}

# ---- status ----

$before = Get-AutologonState

if ($Mode -eq 'status') {
	if ($before.Enabled) {
		Write-Recipe "The automatic logon is ON for $($before.Domain)\$($before.User)"
		exit 0
	}
	Write-Recipe "The automatic logon is off"
	exit 1
}

# ---- off ----

if ($Mode -eq 'off') {
	if (-not $before.Enabled) {
		Write-Recipe "The automatic logon was already off, nothing to do"
		exit 1
	}
	Write-Recipe "Switching the automatic logon off, it was on for $($before.Domain)\$($before.User)"
	# Autologon itself offers no command line for this - the Sysinternals page gives the Disable
	# button and the shift key, and nothing else - so the values are written here. AutoAdminLogon
	# at 0 is what stops Windows; DefaultPassword is removed as well because another tool may have
	# left one there in clear, and that one Windows would read.
	Set-ItemProperty -Path $winlogon -Name 'AutoAdminLogon' -Value '0' -ErrorAction Stop
	foreach ($value in @('DefaultUserName', 'DefaultDomainName', 'DefaultPassword')) {
		Remove-ItemProperty -Path $winlogon -Name $value -ErrorAction SilentlyContinue
	}
	$after = Get-AutologonState
	if ($after.Enabled) {
		Write-Fail "the automatic logon is still on after writing the registry"
		exit 2
	}
	Write-Recipe "The automatic logon is off"
	# The LSA secret Autologon stored stays where it is: only an administrator can read it, the
	# password it holds is the deployment default that the operator changes by hand at the end,
	# and Windows does not use it with AutoAdminLogon at 0.
	exit 0
}

# ---- on ----

if (-not $Username) { $Username = 'itadmin' }

if (-not $Password) {
	$account = Get-AnswerAccount $Answer $Username
	if ($null -eq $account) {
		Write-Fail "no account $Username with a password in $Answer, and none was given on the command line"
		Write-Plain "pass -Password, or point -Answer at the answer file that created the account"
		exit 2
	}
	$Password = $account.Password
	Write-Recipe "Account $Username, password read from $Answer"
}

$exe = $null
foreach ($name in @('Autologon64.exe', 'Autologon.exe', 'Autologon64a.exe')) {
	$candidate = Join-Path $AppPath $name
	if (Test-Path -LiteralPath $candidate) { $exe = $candidate; break }
}
if (-not $exe) {
	Write-Fail "Autologon is not in $AppPath, so the automatic logon cannot be configured"
	Write-Plain "cats install Cats.Utils   puts it there, and the image is where it belongs: the first"
	Write-Plain "restart of a chain can happen before this machine has a network"
	exit 3
}

# The eula, in the registry as well as on the command line: an unattended chain that stops on a
# dialog nobody is in front of is worse than one that does not start
try {
	$eula = 'HKCU:\Software\Sysinternals\Autologon'
	if (-not (Test-Path -LiteralPath $eula)) { New-Item -Path $eula -Force | Out-Null }
	Set-ItemProperty -Path $eula -Name 'EulaAccepted' -Value 1 -ErrorAction Stop
} catch {
	Write-Warn "the Sysinternals eula flag could not be written: $($_.Exception.Message)"
}

# A local account logs on to this machine, so the domain is the machine
$domain = $env:COMPUTERNAME
Write-Recipe "Switching the automatic logon on for $domain\$Username with $([IO.Path]::GetFileName($exe))"
& $exe $Username $domain $Password '/accepteula' | Out-Null

# Read back, always: Autologon does not check what it is given and answers nothing useful
$after = Get-AutologonState
if (-not $after.Enabled) {
	Write-Fail "the automatic logon is not on after running Autologon"
	Write-Plain "Exchange ActiveSync password policies make Windows ignore this configuration, and"
	Write-Plain "Autologon accepts credentials it cannot verify: check the account and its password"
	exit 2
}
if ($after.User -and $after.User -ne $Username) {
	Write-Warn "the automatic logon is on for $($after.Domain)\$($after.User), which is not $Username"
}
Write-Recipe "The automatic logon is on for $($after.Domain)\$($after.User)"
Write-Plain "it is switched off again by the last step of the chain, and by cats-resume when a chain ends"
exit 0
