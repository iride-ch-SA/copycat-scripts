param(
	[string]$username,
	[switch]$all
)

# ============================================================
#  wireguard-operators.ps1
#  Adds local accounts to the built-in "Network Configuration
#  Operators" group, which is the group WireGuard's
#  LimitedOperatorUI grants the tunnel start/stop rights to.
#    -username <name> : one account, local or DOMAIN\user
#    -all             : every enabled, non-administrative local
#                       account of this machine
#  The group is resolved by SID, never by name: on a localised
#  Windows it is called "Operatori di configurazione di rete"
#  and a hardcoded English name does not resolve.
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
	# member is an orphaned SID left by a deleted account, so the
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
		$targets += $user.Name
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
	# A domain or Entra account is not a local user: it is passed
	# through to the group as it was typed
	if ($username -match '[\\@]') {
		$targets += $username
	} else {
		$user = Get-LocalUser -Name $username -ErrorAction SilentlyContinue
		if (-not $user) {
			Write-Problem "ERROR" ("local user '" + $username + "' does not exist") "Red"
			exit 2
		}
		if (-not $user.Enabled) {
			Write-Problem "WARNING" ("'" + $user.Name + "' is disabled, it is added anyway") "Yellow"
		}
		if ($members -contains $user.SID.Value) {
			Write-Recipe ($user.Name + " is already an operator")
			exit 1
		}
		$targets += $user.Name
	}
}

$added = 0
$failed = 0
foreach ($target in $targets) {
	Try {
		Add-LocalGroupMember -SID $netcfg.SID -Member $target -ErrorAction Stop
		Write-Recipe ($target + " can now start and stop the tunnels") "Green"
		$added++
	} Catch {
		# Already a member is the one failure that is not a failure:
		# the machine is in the state that was asked for
		if ($_.Exception.GetType().Name -eq 'PrincipalExistsException') {
			Write-Recipe ($target + " is already an operator")
			$skipped++
		} else {
			Write-Problem "ERROR" ("'" + $target + "' could not be added: " + $_.Exception.Message) "Red"
			$failed++
		}
	}
}

if ($failed -gt 0) { exit 2 }
if ($added -eq 0) { exit 1 }
exit 0
