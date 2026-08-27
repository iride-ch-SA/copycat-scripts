param(
	[string]$username,
	[switch]$all
)

# ============================================================
#  wireguard-operators.ps1
#  Adds accounts to the built-in "Network Configuration
#  Operators" group, which is the group WireGuard's
#  LimitedOperatorUI grants the tunnel start/stop rights to.
#    -username <name> : one account. A local name, DOMAIN\user,
#                       or an Entra account as AzureAD\user@tenant
#    -all             : every enabled, non-administrative local
#                       account of this machine
#  The group is resolved by SID, never by name: on a localised
#  Windows it is called "Operatori di configurazione di rete"
#  and a hardcoded English name does not resolve.
#  Members are resolved by SID too, so that a cloud account -
#  which does not exist in the SAM database the LocalAccounts
#  module reads - can still be added.
#  Exit codes: 0 something was changed, 1 nothing to do, 2 error.
# ============================================================

$NETCFG_SID = 'S-1-5-32-556'
$ADMINS_SID = 'S-1-5-32-544'

function Write-Recipe {
	param([string]$text, [string]$colour = 'Cyan')
	Write-Host ("RECIPE    : " + $text) -ForegroundColor $colour
}

function Write-Problem {
	param([string]$label, [string]$text, [string]$colour)
	Write-Host ($label.PadRight(10) + ": " + $text) -ForegroundColor $colour
}

function Get-GroupMemberSid {
	# Get-LocalGroupMember gives up on the whole group when a single
	# member is an orphaned SID left by a deleted account - and it does
	# the same on a cloud SID it cannot map back to a name - so the
	# WinNT provider is kept as the fallback that always answers.
	param($group)

	Try {
		return @(Get-LocalGroupMember -SID $group.SID -ErrorAction Stop | ForEach-Object { $_.SID.Value })
	} Catch {
		$sids = @()
		Try {
			$adsi = [ADSI]("WinNT://./" + $group.Name + ",group")
			foreach ($member in @($adsi.Invoke('Members'))) {
				Try {
					$bytes = ([ADSI]$member).InvokeGet('objectSID')
					$sids += (New-Object System.Security.Principal.SecurityIdentifier($bytes, 0)).Value
				} Catch {
					# An unresolvable member is not one of the accounts we are about to add
				}
			}
		} Catch {
			Write-Problem "WARNING" ("the members of '" + $group.Name + "' could not be read, every account is treated as not a member") "Yellow"
		}
		return $sids
	}
}

function Get-JoinState {
	# Only called to explain a failure, never on the working path
	Try {
		$status = (& dsregcmd /status 2>$null) -join "`n"
	} Catch {
		return 'unknown'
	}
	if (-not $status) { return 'unknown' }
	if ($status -match 'AzureAdJoined\s*:\s*YES') { return 'entra' }
	if ($status -match 'WorkplaceJoined\s*:\s*YES') { return 'registered' }
	if ($status -match 'DomainJoined\s*:\s*YES') { return 'domain' }
	return 'workgroup'
}

function Resolve-Principal {
	# LookupAccountName - the API behind NTAccount.Translate, behind
	# net localgroup and behind the WinNT provider - is the only thing
	# on the machine that turns AzureAD\user@tenant into a SID: on an
	# Entra joined device the Cloud AP plugin answers for the AzureAD
	# domain. The LocalAccounts module does not go through it, it reads
	# the SAM database, where a cloud account simply is not there.
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

function Add-Operator {
	# Three ways in, tried in order. The first is the cheapest, the last
	# is the one Microsoft documents for cloud accounts; whichever answers,
	# the membership is verified by re-reading the group afterwards.
	param($group, $target)

	$problems = @()

	# 1. The cmdlet, by SID: passing the SID keeps the LocalAccounts
	#    module from having to look a cloud name up in the SAM database
	Try {
		Add-LocalGroupMember -SID $group.SID -Member $target.Sid.Value -ErrorAction Stop
		return @()
	} Catch {
		if ($_.Exception.GetType().Name -eq 'PrincipalExistsException') { return @() }
		$problems += ("Add-LocalGroupMember: " + $_.Exception.Message)
	}

	# 2. The WinNT provider, which speaks LookupAccountName and therefore
	#    knows the AzureAD domain
	Try {
		$path = $target.Name
		if ($path -notmatch '\\') { $path = ($env:COMPUTERNAME + '\' + $path) }
		$adsi = [ADSI]("WinNT://./" + $group.Name + ",group")
		$adsi.Add("WinNT://" + ($path -replace '\\', '/'))
		return @()
	} Catch {
		$problems += ("WinNT: " + $_.Exception.Message)
	}

	# 3. net localgroup, by name
	$output = (& net localgroup $group.Name $target.Name /add 2>&1 | Out-String)
	if ($LASTEXITCODE -eq 0) { return @() }
	$problems += ("net localgroup: " + ($output -replace '\s+', ' ').Trim())

	return $problems
}

if (-not $username -and -not $all) {
	Write-Problem "ERROR" "either -username <name> or -all is expected" "Red"
	exit 2
}

$netcfg = Get-LocalGroup -SID $NETCFG_SID -ErrorAction SilentlyContinue
if (-not $netcfg) {
	Write-Problem "ERROR" ("the Network Configuration Operators group was not found at SID " + $NETCFG_SID) "Red"
	exit 2
}
Write-Recipe ("Group " + $netcfg.Name + " (" + $NETCFG_SID + ")")

$members = Get-GroupMemberSid $netcfg
$targets = @()
$skipped = 0

if ($all) {
	$admins = Get-LocalGroup -SID $ADMINS_SID -ErrorAction SilentlyContinue
	if (-not $admins) {
		Write-Problem "ERROR" ("the Administrators group was not found at SID " + $ADMINS_SID + ", the scan cannot tell administrators apart") "Red"
		exit 2
	}
	$adminSids = Get-GroupMemberSid $admins

	foreach ($user in Get-LocalUser) {
		$sid = $user.SID.Value
		# Built-in accounts - Administrator, Guest, DefaultAccount,
		# WDAGUtilityAccount - are the ones below RID 1000
		$rid = 0
		[void][int]::TryParse(($sid -split '-')[-1], [ref]$rid)
		if ($rid -lt 1000) { continue }

		if (-not $user.Enabled) {
			Write-Recipe ($user.Name + " is disabled, skipped") "DarkGray"
			continue
		}
		if ($adminSids -contains $sid) {
			Write-Recipe ($user.Name + " is an administrator, skipped") "DarkGray"
			continue
		}
		if ($members -contains $sid) {
			Write-Recipe ($user.Name + " is already an operator") "DarkGray"
			$skipped++
			continue
		}
		$targets += [pscustomobject]@{ Name = $user.Name; Sid = $user.SID }
	}

	# The scan reads the SAM database: a cloud account is not in it, and
	# no scan can enumerate who will sign in tomorrow
	if ((Get-JoinState) -eq 'entra') {
		Write-Recipe "This machine is Entra joined: its cloud accounts are not local users, name them one by one with cats prepare WireGuard AzureAD\user@tenant" "Yellow"
	}

	if ($targets.Count -eq 0) {
		if ($skipped -gt 0) {
			Write-Recipe "Every non-administrative account is already an operator"
			exit 1
		}
		Write-Problem "WARNING" "no non-administrative local account was found on this machine" "Yellow"
		exit 1
	}
} else {
	$resolved = Resolve-Principal $username
	if (-not $resolved) {
		Write-Problem "ERROR" ("'" + $username + "' is not a name this machine can resolve to an account") "Red"
		switch (Get-JoinState) {
			'entra' {
				Write-Problem "ERROR" "the machine is Entra joined, so the expected form is AzureAD\user@tenant - check the spelling of the UPN, and that the tenant is reachable" "Red"
			}
			'registered' {
				Write-Problem "ERROR" "the machine is Entra registered, not Entra joined: cloud accounts are not local principals here and cannot be group members" "Red"
			}
			'domain' {
				Write-Problem "ERROR" "the machine is domain joined and not Entra joined, so the expected form is DOMAIN\user" "Red"
			}
			'workgroup' {
				Write-Problem "ERROR" "the machine is in a workgroup: only its local accounts can be named" "Red"
			}
			default {
				Write-Problem "ERROR" "the join state of the machine could not be read with dsregcmd" "Red"
			}
		}
		exit 2
	}

	if ($resolved.Name -ne $username) {
		Write-Recipe ("'" + $username + "' resolved as " + $resolved.Name)
	}
	Write-Recipe ($resolved.Name + " is " + $resolved.Sid.Value)

	$local = Get-LocalUser -SID $resolved.Sid.Value -ErrorAction SilentlyContinue
	if ($local -and -not $local.Enabled) {
		Write-Problem "WARNING" ("'" + $local.Name + "' is disabled, it is added anyway") "Yellow"
	}
	if ($members -contains $resolved.Sid.Value) {
		Write-Recipe ($resolved.Name + " is already an operator")
		exit 1
	}
	$targets += $resolved
}

$results = @()
foreach ($target in $targets) {
	$results += [pscustomobject]@{ Target = $target; Problems = (Add-Operator $netcfg $target) }
}

# Whichever way answered, the group is read back: the script this one
# replaces reported success while adding nobody, and that is the failure
# a re-read makes impossible
$members = Get-GroupMemberSid $netcfg
$added = 0
$failed = 0

foreach ($result in $results) {
	$name = $result.Target.Name
	$sid = $result.Target.Sid.Value
	# An empty array coming back from a function is unrolled into nothing,
	# that is, into $null: it is re-wrapped rather than counted as it is
	$problems = @($result.Problems | Where-Object { $_ })

	if ($members -contains $sid) {
		Write-Recipe ($name + " can now start and stop the tunnels") "Green"
		$added++
		continue
	}
	if ($problems.Count -eq 0) {
		Write-Problem "WARNING" ("'" + $name + "' was added, but reading the group back does not show it - check with: net localgroup """ + $netcfg.Name + """") "Yellow"
		$added++
		continue
	}
	Write-Problem "ERROR" ("'" + $name + "' could not be added: " + ($problems -join ' | ')) "Red"
	$failed++
}

if ($failed -gt 0) { exit 2 }
if ($added -eq 0) { exit 1 }
exit 0
