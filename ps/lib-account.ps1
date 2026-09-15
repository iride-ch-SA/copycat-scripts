# ============================================================
#  lib-account.ps1
#  Not a script to run: a library the account scripts of this
#  repository dot-source, with the two questions about a name
#  that more than one of them asks.
#    . (Join-Path $PSScriptRoot 'lib-account.ps1')
#  Resolve-Principal   : a typed name -> the SID of a principal
#                        this machine knows, local, domain or
#                        Entra. One cascade, one contract.
#  Test-LocalAccountName : is this a name a LOCAL account can be
#                        created under? It is a guard, not a
#                        translation: a domain or an Entra
#                        account has no local counterpart and
#                        the right answer is to refuse.
#  Kept apart because the same cascade lived in three copies -
#  set-localgroup-member.ps1, wireguard-operators.ps1 and
#  resolve-logon-name.ps1 - and had already drifted: two of them
#  handed back a SecurityIdentifier in Sid and the third a
#  string, so a line moved between them would have compared a
#  SID with its own text and never matched, which in these
#  scripts reads as "not a member" said of a member.
#  The contract here is the one two of the three already used:
#  Sid is the SecurityIdentifier object, Sid.Value its text.
# ============================================================

function Resolve-Principal {
	# LookupAccountName - the API behind NTAccount.Translate, behind net
	# localgroup and behind the WinNT provider - is the only thing on the
	# machine that turns AzureAD\user@tenant into a SID: on an Entra
	# joined device the Cloud AP plugin answers for the AzureAD domain.
	# The LocalAccounts module does not go through it: it reads the SAM
	# database, where a cloud account is not present at all.
	# Returns $null when no form of the name resolves, which is not the
	# same as an error: the account may simply not be known here yet.
	param([string]$name)

	$forms = @($name)
	if ($name -notmatch '\\' -and $name -match '@') {
		# A bare UPN: the machine expects it prefixed
		$forms += ('AzureAD\' + $name)
	}
	if ($name -match '^(?i)azuread\\(.+)$') {
		# Hybrid case: the same UPN belongs to the on-premises domain
		$forms += $Matches[1]
	}

	foreach ($form in $forms) {
		Try {
			$sid = (New-Object System.Security.Principal.NTAccount($form)).Translate([System.Security.Principal.SecurityIdentifier])
			return [pscustomobject]@{ Name = $form; Sid = $sid }
		} Catch {
			# Not a name this machine knows in that form, the next one is tried
		}
	}
	return $null
}

function Test-LocalAccountName {
	# Answers with $null when the name can be that of a local account,
	# and with the reason why not when it cannot. Nothing is measured
	# here and nothing needs to be: the point is what the name IS, not
	# whether it exists. An account named after a UPN would be created
	# by New-LocalUser without complaint - @ is not among the characters
	# the SAM database forbids - and a local homonym of a cloud account
	# is exactly what must not happen.
	param([string]$name)

	if (-not $name -or -not $name.Trim()) {
		return 'no name was given'
	}

	# The name is judged exactly as it was given, never trimmed first: the
	# callers create the account, set its password and write its registry
	# value under the string THEY were handed, so a guard that passed
	# judgement on a different string would be the same "one name is
	# checked and another is used" this file exists to remove. A name with
	# a blank at either end is therefore refused here, where the reason can
	# be named, instead of reaching New-LocalUser and coming back as a
	# message of its own.
	if ($name -ne $name.Trim()) {
		return "'" + $name + "' begins or ends with a space or a tab, and the name is used here exactly as it was typed"
	}

	if ($name -match '@') {
		return "'" + $name + "' is a user principal name, so it names an Entra account and not a local one"
	}
	if ($name -match '\\') {
		return "'" + $name + "' carries a domain prefix, so it names a domain account and not a local one"
	}
	if ($name.Length -gt 20) {
		return "'" + $name + "' is longer than the 20 characters a local account name can have"
	}
	if ($name -match '["/\[\]:;\|=,\+\*\?<>]') {
		return "'" + $name + "' contains a character a local account name cannot have, one of " + [char]34 + ' / \ [ ] : ; | = , + * ? < >'
	}
	if ($name -match '^[\. ]+$') {
		return "'" + $name + "' is made of dots and spaces only"
	}
	if ($name.EndsWith('.')) {
		return "'" + $name + "' ends with a dot"
	}

	return $null
}
