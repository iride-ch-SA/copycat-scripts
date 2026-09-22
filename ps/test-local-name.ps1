[CmdletBinding()]
param(
	[string]$username
)

# An unhandled error is named on the console, with the line it came from, before the
# exit code reaches the caller. Every helper of this repository answers the same way.
trap {
	Write-Host ("ERROR     : test-local-name failed: " + $_.Exception.Message + " [line " + $_.InvocationInfo.ScriptLineNumber + "]") -ForegroundColor Red
	exit 2
}

# ============================================================
#  test-local-name.ps1
#  Says whether a name is one a LOCAL account can be created
#  under, and nothing else: it is the guard cats create User
#  asks for before any of its three paths runs.
#    -username <name> : the name as it was typed, judged as it
#                       was typed: a name with a space at either
#                       end is refused, not trimmed, because the
#                       caller creates the account under the
#                       string it was handed
#  Exit codes: 0 the name is that of a local account, 2 it is
#  not, and the reason is on standard error. Nothing is written
#  to standard output either way: callers capture that stream.
#  Why a guard and not a conversion: cats create User creates
#  local accounts, it does not create accounts in a domain nor
#  in a tenant, and a name that does not suit a local account
#  has no local counterpart to be converted into. Left alone,
#  New-LocalUser would take gianni@tenant.ch - @ is not among
#  the characters the SAM database forbids - and a local
#  homonym of a cloud account would be born, then duly added
#  to Users and Remote Desktop Users, with no error anywhere.
#  For an account that lives in a domain or in a tenant the
#  verbs that apply are cats prepare Userlogin and cats prepare
#  WireGuard, which work on the account as it is.
# ============================================================

# Test-LocalAccountName, shared with the other account scripts
. (Join-Path $PSScriptRoot 'lib-account.ps1')

$why = Test-LocalAccountName $username
if ($why) {
	[Console]::Error.WriteLine("ERROR     : " + $why)
	exit 2
}

exit 0
