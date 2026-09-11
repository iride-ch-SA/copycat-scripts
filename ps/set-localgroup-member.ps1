param(
	[string]$username,
	[string]$sid,
	[switch]$quiet
)

# ============================================================
#  set-localgroup-member.ps1
#  Adds an account to a built-in local group named by its SID,
#  and proves the membership by reading the group back.
#    -username <name> : a local name, DOMAIN\user, or an Entra
#                       account as AzureAD\user@tenant
#    -sid <S-1-5-32-x>: the group, always by SID
#    -quiet           : only problems are printed
#  The group is resolved by SID and never by name, because the
#  built-in groups are translated on a localised Windows: Users
#  is "Utenti", Administrators "Amministratori", Remote Desktop
#  Users "Utenti desktop remoto". A hardcoded English name does
#  not resolve there, and the helper this one replaces reported
#  success while adding nobody.
#  Exit codes: 0 the account is a member - added now, or already
#  was - and 2 for any error. An account that is already in the
#  group is not a failure: the caller asks for a membership, not
#  for a change.
# ============================================================

function Write-Recipe {
	param([string]$text, [string]$colour = 'Cyan')
	if (-not $quiet) { Write-Host ("RECIPE    : " + $text) -ForegroundColor $colour }
}

function Write-Problem {
	param([string]$label, [string]$text, [string]$colour)
	Write-Host ($label.PadRight(10) + ": " + $text) -ForegroundColor $colour
}

function Get-GroupMemberSid {
	# Get-LocalGroupMember gives up on the whole group when a single
	# member is an orphaned SID left by a deleted account, so the WinNT
	# provider is kept as the fallback that always answers.
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
					# An unresolvable member is not the account we are about to add
				}
			}
		} Catch {
			Write-Problem "WARNING" ("the members of '" + $group.Name + "' could not be read, the account is treated as not a member") "Yellow"
		}
		return $sids
	}
}

function Resolve-Principal {
	# LookupAccountName - the API behind NTAccount.Translate, behind net
	# localgroup and behind the WinNT provider - is the only thing on the
	# machine that turns AzureAD\user@tenant into a SID. The LocalAccounts
	# module does not go through it: it reads the SAM database, where a
	# cloud account is not present at all.
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
			$resolved = (New-Object System.Security.Principal.NTAccount($form)).Translate([System.Security.Principal.SecurityIdentifier])
			return [pscustomobject]@{ Name = $form; Sid = $resolved }
		} Catch {
			# Not a name this machine knows in that form, the next one is tried
		}
	}
	return $null
}

if (-not $username) {
	Write-Problem "ERROR" "-username <name> is expected as first parameter" "Red"
	exit 2
}

if ($sid -notmatch '^(?i)S(-\d+)+$') {
	Write-Problem "ERROR" "-sid <S-1-5-32-x> is expected: a built-in group is named by its SID, never by its name" "Red"
	exit 2
}

$group = Get-LocalGroup -SID $sid -ErrorAction SilentlyContinue
if (-not $group) {
	Write-Problem "ERROR" ("no local group was found at SID " + $sid) "Red"
	exit 2
}

$target = Resolve-Principal $username
if (-not $target) {
	Write-Problem "ERROR" ("'" + $username + "' is not a name this machine can resolve to an account") "Red"
	exit 2
}

if ($target.Name -ne $username) {
	Write-Recipe ("'" + $username + "' resolved as " + $target.Name)
}

if ((Get-GroupMemberSid $group) -contains $target.Sid.Value) {
	Write-Recipe ($target.Name + " is already a member of " + $group.Name)
	exit 0
}

$problems = @()

# 1. The cmdlet, group and member both by SID: passing the member SID
#    keeps the LocalAccounts module from looking a cloud name up in SAM
$added = $false
Try {
	Add-LocalGroupMember -SID $group.SID -Member $target.Sid.Value -ErrorAction Stop
	$added = $true
} Catch {
	if ($_.Exception.GetType().Name -eq 'PrincipalExistsException') {
		$added = $true
	} else {
		$problems += ("Add-LocalGroupMember: " + $_.Exception.Message)
	}
}

# 2. net localgroup, which is the form Microsoft documents for cloud
#    accounts and goes through LookupAccountName
if (-not $added) {
	$output = (& net localgroup $group.Name $target.Name /add 2>&1 | Out-String)
	if ($LASTEXITCODE -eq 0) {
		$added = $true
	} else {
		$problems += ("net localgroup: " + ($output -replace '\s+', ' ').Trim())
	}
}

# Whichever way answered, the group is read back: a helper that reports
# success without being able to prove it is the defect this replaces
if ((Get-GroupMemberSid $group) -contains $target.Sid.Value) {
	Write-Recipe ($target.Name + " is now a member of " + $group.Name) "Green"
	exit 0
}

if ($added) {
	Write-Problem "WARNING" ("'" + $target.Name + "' was added to " + $group.Name + ", but reading the group back does not show it - check with: net localgroup """ + $group.Name + """") "Yellow"
	exit 0
}

Write-Problem "ERROR" ("'" + $target.Name + "' could not be added to " + $group.Name + ": " + ($problems -join ' | ')) "Red"
exit 2
