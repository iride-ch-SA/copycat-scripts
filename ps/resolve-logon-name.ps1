[CmdletBinding()]
param(
	[string]$username,
	[switch]$local,
	[switch]$quiet
)

# An unhandled error used to leave the caller with a bare exit code and no reason to
# read. Every helper of this repository answers the same way since 2026-09-22.
trap {
	Write-Host ("ERROR     : resolve-logon-name failed: " + $_.Exception.Message + " [line " + $_.InvocationInfo.ScriptLineNumber + "]") -ForegroundColor Red
	exit 2
}

# ============================================================
#  resolve-logon-name.ps1
#  Prints the name a given account has in %USERNAME% once it
#  signs in, which is the name the per user files of this
#  repository are called after - C:\Admin\Others\<name>.bat in
#  userlogin.bat, C:\Admin\Others\<name>.bgi in
#  set-background.bat.
#    -username <name> : a local name, DOMAIN\user, an Entra
#                       account as user@tenant or
#                       AzureAD\user@tenant
#    -quiet           : only problems are printed
#  The name goes to standard output on a line of its own and
#  nothing else does, because the caller captures it with a
#  for /f, which takes standard output and drops standard error.
#  Every message is therefore written to standard error, where
#  the operator still reads it.
#  What is typed is not what Windows uses: a domain account signs
#  in as its sAMAccountName, which needs not be the prefix of its
#  UPN, and an Entra account signs in under a name the Cloud AP
#  plugin makes up from the UPN. So the name is measured on the
#  machine wherever the machine can answer, and only derived from
#  what was typed as the last resort - and that case says so.
#  Four sources, in this order:
#    1. HKU\<SID>\Volatile Environment, which holds the very
#       USERNAME of a session that is open right now;
#    2. LookupAccountSid, authoritative for a local or a domain
#       account, where the name it returns is the one that signs
#       in. It answers an Entra account with its UPN, which is
#       not that name, so that answer is left to source 3;
#    3. the leaf of ProfileImagePath under ProfileList, the name
#       Windows gave the profile folder of that SID - the only
#       measurable source for an Entra account that has signed
#       in at least once;
#    4. what was typed, less any DOMAIN\ prefix and any @tenant
#       suffix. Derived, not measured: a WARNING is printed.
#    -local           : the account has to be a local one, and
#                       nothing is derived. It is the form the
#                       callers that write something per local
#                       account need - the value under Winlogon
#                       SpecialAccounts UserList, which has no
#                       effect on a domain or an Entra account -
#                       and there an unresolved name is an error,
#                       not a case for the last resort.
#  Exit codes: 0 the name is on standard output, 2 for any error
#  and then standard output is empty.
# ============================================================

# The cascade that turns a typed name into a SID is shared with the other
# account scripts of this repository and lives in one file only: three
# copies of it had already drifted apart. Resolve-Principal and
# Test-LocalAccountName come from there.
. (Join-Path $PSScriptRoot 'lib-account.ps1')


$forbidden = '[\\/:\*\?"<>\|]'

function Write-Note {
	param([string]$text)
	if (-not $quiet) { [Console]::Error.WriteLine("RECIPE    : " + $text) }
}

function Write-Problem {
	param([string]$label, [string]$text)
	[Console]::Error.WriteLine($label.PadRight(10) + ": " + $text)
}

function Get-VolatileName {
	# A session that is open right now has its own environment in the
	# registry, and USERNAME there is the string being looked for, with
	# no derivation of any kind
	param([string]$sid)

	Try {
		$value = (Get-ItemProperty -Path ("Registry::HKEY_USERS\" + $sid + "\Volatile Environment") -Name 'USERNAME' -ErrorAction Stop).USERNAME
	} Catch {
		return $null
	}
	if ($value) { return $value.Trim() }
	return $null
}

function Get-AccountName {
	# The name LookupAccountSid gives back, without its domain part
	param([string]$sid)

	Try {
		$full = (New-Object System.Security.Principal.SecurityIdentifier($sid)).Translate([System.Security.Principal.NTAccount]).Value
	} Catch {
		return $null
	}
	if (-not $full) { return $null }
	if ($full -match '\\') { return $full.Substring($full.IndexOf('\') + 1) }
	return $full
}

function Get-ProfileName {
	# The leaf of the profile folder Windows created for that SID. For a
	# domain account it can carry a .DOMAIN or .000 suffix of a profile
	# conflict, which is why source 2 is asked first
	param([string]$sid)

	Try {
		$path = (Get-ItemProperty -Path ("Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\" + $sid) -Name 'ProfileImagePath' -ErrorAction Stop).ProfileImagePath
	} Catch {
		return $null
	}
	if (-not $path) { return $null }
	return (Split-Path -Path $path.TrimEnd('\') -Leaf)
}

function Get-TypedName {
	# The last resort: what was typed, stripped of what Windows does not
	# put in USERNAME
	param([string]$name)

	$bare = $name
	if ($bare -match '\\') { $bare = $bare.Substring($bare.IndexOf('\') + 1) }
	if ($bare -match '@') { $bare = $bare.Substring(0, $bare.IndexOf('@')) }
	return $bare
}

if (-not $username) {
	Write-Problem "ERROR" "-username <name> is expected as first parameter"
	exit 2
}

# Trimmed before anything else, and deliberately before the guard too: what
# this script hands back is the name MEASURED on the machine, not the one
# typed, so the string judged here and the string used here are the same one.
# Test-LocalAccountName refuses a name with a space at either end, because
# its other callers do create an account under the string they were given.
$name = $username.Trim()

if ($local) {
	$why = Test-LocalAccountName $name
	if ($why) {
		Write-Problem "ERROR" ($why + ", and what is being asked for applies to local accounts only")
		exit 2
	}
}

$target = Resolve-Principal $name

if ($local -and -not $target) {
	Write-Problem "ERROR" ("'" + $name + "' is not an account this machine knows: nothing is guessed here, because a name that is wrong would be written down and take effect on nobody")
	exit 2
}

if ($local -and -not (Get-LocalUser -SID $target.Sid.Value -ErrorAction SilentlyContinue)) {
	Write-Problem "ERROR" ("'" + $name + "' resolves to " + $target.Sid.Value + ", which is not a local account of this machine, and what is being asked for applies to local accounts only")
	exit 2
}

if ($target) {
	if ($target.Name -ne $name) {
		Write-Note ("'" + $name + "' resolved as " + $target.Name)
	}

	$measured = Get-VolatileName $target.Sid.Value
	if ($measured) {
		Write-Note ($target.Name + " signs in as " + $measured + ", read from the session open right now")
	}

	if (-not $measured) {
		$account = Get-AccountName $target.Sid.Value
		# An Entra account answers with its UPN here, and that is not the
		# name it signs in under: the profile folder is asked instead
		if ($account -and $account -notmatch '@') {
			$measured = $account
			Write-Note ($target.Name + " signs in as " + $measured + ", the account name of " + $target.Sid.Value)
		}
	}

	if (-not $measured) {
		$folder = Get-ProfileName $target.Sid.Value
		if ($folder) {
			$measured = $folder
			Write-Note ($target.Name + " signs in as " + $measured + ", the name of its profile folder")
		}
	}

	if ($measured -and $measured -notmatch $forbidden) {
		[Console]::Out.WriteLine($measured)
		exit 0
	}

	if ($measured) {
		Write-Problem "WARNING" ("'" + $measured + "' cannot be part of a file name, so the name as typed is used instead")
	}
} else {
	Write-Problem "WARNING" ("'" + $name + "' is not a name this machine can resolve to an account: it may not have signed in here yet, or the tenant may be out of reach")
}

if ($local) {
	Write-Problem "ERROR" ("the name '" + $name + "' signs in under could not be read on this machine, and with -local it is not derived from what was typed")
	exit 2
}

$typed = Get-TypedName $name
if (-not $typed -or $typed -match $forbidden) {
	Write-Problem "ERROR" ("no usable sign-in name can be made out of '" + $name + "'")
	exit 2
}

Write-Problem "WARNING" ("'" + $typed + "' is derived from what was typed and not measured on this machine: check it against what echo %USERNAME% prints in a session of that user")
[Console]::Out.WriteLine($typed)
exit 0
