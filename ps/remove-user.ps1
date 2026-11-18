# ============================================================
#  remove-user.ps1
#  Takes an account off this machine: cats remove User <name>.
#  The account is first told apart by its SID, because what
#  "remove" can mean depends on where the account lives:
#    local     S-1-5-21-<this machine>-<RID>, in the SAM: the
#              account itself is deleted
#    domain    S-1-5-21-<the domain>-<RID>: the account lives in
#              the domain and is NOT deleted there - what goes is
#              what this machine holds of it
#    tenant    S-1-12-1-..., an Entra (tenant 365) account: as
#              for a domain account, what this machine holds
#  What this machine holds of an account, and what is taken:
#    - its membership of every local group, Administrators,
#      Users, Remote Desktop Users, Network Configuration
#      Operators included (a deleted local account leaves them
#      by itself, a domain or tenant account does not)
#    - its place on the sign-in screen: the value that hides a
#      local account under Winlogon SpecialAccounts UserList, the
#      last-signed-in tile under LogonUI when it is this account,
#      and for a domain or tenant account the identity Windows
#      cached at its first sign-in under IdentityStore, which is
#      what keeps a tenant account offered on the sign-in screen
#    - its profile, C:\Users\<name> and the ProfileList entry,
#      after a question: see -ProfileMode below
#
#    -username <name>  as typed: mario, DOMAIN\mario,
#                      AzureAD\mario@tenant, mario@tenant, or the
#                      SID itself. A tenant or domain account the
#                      machine can no longer translate - offline,
#                      or already gone from the directory - is
#                      looked for among the names Windows cached
#                      at its first sign-in; failing that the
#                      profiles are listed, and the SID is typed
#    -ProfileMode ask     a y/n question, n to anything but y:
#                         y deletes the profile, n keeps it
#    -ProfileMode delete  the profile is deleted, no question
#    -ProfileMode keep    the profile is kept, no question
#
#  A profile that is kept stays on disk as a folder, with every
#  file in it, and leaves the ProfileList: otherwise Windows goes
#  on treating it as the profile of an account and offering it.
#  The ProfileList entry is exported first to
#  C:\Admin\Others\Profiles\<SID>.reg, which is what imports it
#  back if a domain or tenant account - whose SID does not change -
#  has to find its profile again.
#
#  Refused, with nothing touched: an account this machine does
#  not know; the account running this; the built-in accounts
#  (RID below 1000); the last enabled local administrator; an
#  account that is signed in, whose profile is in use; a run that
#  is not elevated.
#
#  A domain account keeps the rights the domain gives it: Domain
#  Users is a member of Users, so the account can sign in again
#  and gets a new profile. A tenant account the same, wherever the
#  tenant lets its users sign in to joined devices. This removes
#  the account from the machine as it stands, it does not bar it.
#
#  Exit codes: 0 removed; 1 refused, nothing was touched; 2 the
#  account was removed in part, the lines above say what stayed.
# ============================================================

[CmdletBinding()]
param(
	[string]$username,
	[ValidateSet('ask', 'delete', 'keep')]
	[string]$ProfileMode = 'ask'
)

# An unhandled error is named on the console, with the line it came from, before the
# exit code reaches the caller. Every helper of this repository answers the same way.
trap {
	Write-Host ("ERROR     : remove-user failed: " + $_.Exception.Message + " [line " + $_.InvocationInfo.ScriptLineNumber + "]") -ForegroundColor Red
	exit 2
}

. (Join-Path $PSScriptRoot 'lib-account.ps1')

function Write-Recipe([string]$text) { Write-Host ("RECIPE    : " + $text) -ForegroundColor Cyan }
function Write-Warn([string]$text)   { Write-Host ("WARNING   : " + $text) -ForegroundColor Yellow }
function Write-Refusal([string]$text) { Write-Host ("ERROR     : " + $text + ", nothing was touched") -ForegroundColor Red }

$ProfileListKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
$ProfileGuidKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileGuid'
$UserListKey    = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList'
$LogonUIKey     = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI'
$IdentityKey    = 'HKLM:\SOFTWARE\Microsoft\IdentityStore'

function Get-ProfileSid {
	# Every SID that has an entry in ProfileList, with the folder it points at
	$found = @()
	foreach ($key in @(Get-ChildItem -Path $ProfileListKey -ErrorAction SilentlyContinue)) {
		$path = (Get-ItemProperty -Path $key.PSPath -Name ProfileImagePath -ErrorAction SilentlyContinue).ProfileImagePath
		$found += [pscustomobject]@{ Sid = $key.PSChildName; Path = [string]$path }
	}
	return $found
}

function Get-CachedName([string]$sid) {
	# The names Windows cached for a domain or tenant account at its first sign-in,
	# under IdentityStore\Cache\<SID>\IdentityCache\<SID>: the UPN in UserName, and
	# the SAM name. Nothing for a local account, which has no entry there
	$names = @()
	$item = Get-ItemProperty -Path ($IdentityKey + '\Cache\' + $sid + '\IdentityCache\' + $sid) -ErrorAction SilentlyContinue
	if ($item) {
		foreach ($value in @($item.UserName, $item.SAMName)) {
			if ($value) { $names += [string]$value }
		}
	}
	return $names
}

function Find-Account([string]$name) {
	# 1. A SID typed as such
	if ($name -match '^(?i)S-1-\d+(-\d+)+$') {
		return [pscustomobject]@{ Name = $name; Sid = $name.ToUpper(); How = 'typed as a SID' }
	}

	# 2. The cascade every account script of this repository uses, see lib-account.ps1
	$principal = Resolve-Principal $name
	if ($principal) {
		return [pscustomobject]@{ Name = $principal.Name; Sid = $principal.Sid.Value; How = 'translated by this machine' }
	}

	# 3. What the machine still holds of an account it can no longer translate - a
	#    tenant account with the device offline, an account gone from the directory:
	#    the names cached at its first sign-in. The folder name of a profile is NOT
	#    taken as a name: it is a guess - mario can be the folder of an account long
	#    deleted - and the next step deletes things. The bare name is compared too,
	#    mario@tenant for AzureAD\mario@tenant
	$bare = ($name -replace '^.*\\', '')
	$wanted = @($name, $bare) | Select-Object -Unique
	$hits = @()
	foreach ($entry in (Get-ProfileSid)) {
		foreach ($candidate in @(Get-CachedName $entry.Sid)) {
			if ($wanted -contains $candidate) { $hits += $entry.Sid; break }
		}
	}
	$hits = @($hits | Select-Object -Unique)
	if ($hits.Count -eq 1) {
		return [pscustomobject]@{ Name = $name; Sid = $hits[0]; How = 'found among the identities cached on this machine' }
	}
	if ($hits.Count -gt 1) {
		Write-Warn ("'" + $name + "' matches more than one cached identity: " + ($hits -join ', '))
	}
	return $null
}

function Get-AccountKind([string]$sid) {
	# The SID says where the account lives. A local account is the one the SAM
	# answers for; S-1-12-1 is the prefix Entra gives its accounts; any other
	# S-1-5-21 belongs to a domain. Anything else - a service, a well-known SID -
	# is not an account this removes
	$local = $null
	try { $local = Get-LocalUser -SID $sid -ErrorAction Stop } catch { }
	if ($local) { return [pscustomobject]@{ Kind = 'local'; Local = $local } }
	# A SID of this machine the SAM no longer answers for: a local account deleted
	# already, of which a profile or a membership is left. Without this check its
	# S-1-5-21 would read as a domain account
	$machine = @(Get-LocalUser -ErrorAction SilentlyContinue | Select-Object -First 1)
	if ($machine.Count -eq 1 -and $machine[0].SID.AccountDomainSid) {
		if ($sid -like ($machine[0].SID.AccountDomainSid.Value + '-*')) { return [pscustomobject]@{ Kind = 'local'; Local = $null } }
	}
	if ($sid -like 'S-1-12-1-*') { return [pscustomobject]@{ Kind = 'tenant'; Local = $null } }
	if ($sid -like 'S-1-5-21-*') { return [pscustomobject]@{ Kind = 'domain'; Local = $null } }
	return [pscustomobject]@{ Kind = 'other'; Local = $null }
}

function Get-GroupMemberSid {
	# As in set-localgroup-member.ps1: Get-LocalGroupMember gives up on the whole group
	# when one member is an orphaned SID, or an Entra account it cannot name, so the
	# WinNT provider is the fallback that always answers
	param($group)

	try {
		return @(Get-LocalGroupMember -SID $group.SID -ErrorAction Stop | ForEach-Object { $_.SID.Value })
	} catch {
		$sids = @()
		try {
			$adsi = [ADSI]("WinNT://./" + $group.Name + ",group")
			foreach ($member in @($adsi.Invoke('Members'))) {
				try {
					$bytes = ([ADSI]$member).InvokeGet('objectSID')
					$sids += (New-Object System.Security.Principal.SecurityIdentifier($bytes, 0)).Value
				} catch {
					# A member that cannot be read is not the one looked for
				}
			}
		} catch {
			Write-Warn ("the members of '" + $group.Name + "' could not be read")
		}
		return $sids
	}
}

function Remove-GroupMembership([string]$sid) {
	# Every local group the SID is a member of, read back after the removal.
	# Remove-LocalGroupMember first, the WinNT provider - which takes a member by
	# its SID - when the first one refuses. Returns how many stayed
	$stayed = 0
	foreach ($group in @(Get-LocalGroup)) {
		if (-not ((Get-GroupMemberSid $group) -contains $sid)) { continue }
		try {
			Remove-LocalGroupMember -SID $group.SID -Member $sid -ErrorAction Stop
		} catch {
			try {
				$adsi = [ADSI]("WinNT://./" + $group.Name + ",group")
				$adsi.Remove("WinNT://" + $sid)
			} catch { }
		}
		if ((Get-GroupMemberSid $group) -contains $sid) {
			Write-Warn ("still a member of '" + $group.Name + "'")
			$stayed++
		} else {
			Write-Recipe ("Taken out of the group '" + $group.Name + "'")
		}
	}
	return $stayed
}

# ---- 1. Who runs this, and on whom ----

if (-not $username) {
	Write-Refusal "-username <name> is expected"
	exit 1
}

$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
if (-not (New-Object System.Security.Principal.WindowsPrincipal($identity)).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
	Write-Refusal "removing an account needs an elevated prompt: open it with Run as administrator"
	exit 1
}

$account = Find-Account $username
if (-not $account) {
	Write-Refusal ("'" + $username + "' is not an account this machine knows")
	# The profiles of accounts this machine cannot name, so that the operator can
	# give the SID of the one meant: a tenant account with the device offline, an
	# account gone from the domain or deleted
	$unnamed = @(Get-ProfileSid | Where-Object { $_.Sid -like 'S-1-5-21-*' -or $_.Sid -like 'S-1-12-1-*' } | Where-Object {
		try { (New-Object System.Security.Principal.SecurityIdentifier($_.Sid)).Translate([System.Security.Principal.NTAccount]) | Out-Null; $false } catch { $true }
	})
	foreach ($entry in $unnamed) {
		Write-Host ("USAGE     : profile of an account this machine cannot name: " + $entry.Path + "  " + $entry.Sid) -ForegroundColor Blue
	}
	if ($unnamed.Count -gt 0) { Write-Host "USAGE     : cats remove User <SID> takes the account a profile belongs to" -ForegroundColor Blue }
	exit 1
}
$sid = $account.Sid
$kind = Get-AccountKind $sid

$label = @{ local = 'local account'; domain = 'domain account'; tenant = 'tenant 365 (Entra) account'; other = 'not an account' }[$kind.Kind]
Write-Recipe ("'" + $username + "' is a " + $label + ", " + $sid + ", " + $account.How)

# ---- 2. What is refused ----

if ($kind.Kind -eq 'other') {
	Write-Refusal ($sid + " is a built-in or a service identity, not an account this removes")
	exit 1
}
if ($sid -eq $identity.User.Value) {
	Write-Refusal "this is the account running this prompt: sign in with another administrator"
	exit 1
}
if ($kind.Kind -eq 'local') {
	$rid = [int64]($sid -replace '^.*-', '')
	if ($rid -lt 1000) {
		Write-Refusal ($sid + " is a built-in account of Windows")
		exit 1
	}
	# Removing the last enabled local administrator leaves a machine that only a
	# domain or a tenant can administer, and on a machine in a workgroup none at all
	$admins = Get-LocalGroup -SID 'S-1-5-32-544'
	$members = @(Get-GroupMemberSid $admins)
	$others = @($members | Where-Object { $_ -ne $sid } | ForEach-Object {
		try { Get-LocalUser -SID $_ -ErrorAction Stop } catch { }
	} | Where-Object { $_ -and $_.Enabled })
	if ($kind.Local -and $members -contains $sid -and $others.Count -eq 0) {
		Write-Refusal ($kind.Local.Name + " is the last enabled local administrator of this machine")
		exit 1
	}
}

$userProfile = Get-CimInstance -ClassName Win32_UserProfile -Filter ("SID='" + $sid + "'") -ErrorAction SilentlyContinue
if ($userProfile -and $userProfile.Loaded) {
	Write-Refusal ("the account is signed in and its profile is in use: sign it out, or restart the machine, and run this again")
	exit 1
}

# ---- 3. The profile, asked before anything changes ----

$deleteProfile = $false
if ($userProfile) {
	if ($ProfileMode -eq 'ask') {
		$answer = Read-Host ("Delete the profile of " + $username + " too, " + $userProfile.LocalPath + ", with every file in it? [y/N]")
		$deleteProfile = ($answer -match '^\s*(y|yes)\s*$')
	} else {
		$deleteProfile = ($ProfileMode -eq 'delete')
	}
} else {
	Write-Recipe "No profile of this account on this machine"
}

$stayed = 0

# ---- 4. Groups ----

# A local account leaves its groups when it is deleted; a domain or tenant account
# has to be taken out of them, or it stays an administrator of a machine it was
# removed from
if (-not $kind.Local) {
	$stayed += (Remove-GroupMembership $sid)
}

# ---- 5. The profile ----

if ($userProfile) {
	if ($deleteProfile) {
		Write-Recipe ("Deleting the profile " + $userProfile.LocalPath)
		try {
			# Win32_UserProfile deletes the folder, the ProfileList and the ProfileGuid
			# entries together, which is what User Profiles in System Properties does
			Remove-CimInstance -InputObject $userProfile -ErrorAction Stop
		} catch {
			Write-Warn ("the profile could not be deleted: " + $_.Exception.Message)
		}
		if (Test-Path -LiteralPath $userProfile.LocalPath) {
			Write-Warn ($userProfile.LocalPath + " is still on disk, in part or whole")
			$stayed++
		}
	} else {
		Write-Recipe ("Keeping the profile folder " + $userProfile.LocalPath + ", taking it off the ProfileList")
		$backup = 'C:\Admin\Others\Profiles'
		New-Item -ItemType Directory -Path $backup -Force | Out-Null
		& reg.exe export ('HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\' + $sid) (Join-Path $backup ($sid + '.reg')) /y | Out-Null
		if ($LASTEXITCODE -ne 0) {
			Write-Warn "the ProfileList entry could not be exported, so it is left where it is"
			$stayed++
		} else {
			Write-Recipe ("ProfileList entry saved to " + (Join-Path $backup ($sid + '.reg')))
			$guid = (Get-ItemProperty -Path ($ProfileListKey + '\' + $sid) -Name Guid -ErrorAction SilentlyContinue).Guid
			Remove-Item -Path ($ProfileListKey + '\' + $sid) -Recurse -Force -ErrorAction SilentlyContinue
			if ($guid) { Remove-Item -Path ($ProfileGuidKey + '\' + $guid) -Recurse -Force -ErrorAction SilentlyContinue }
			if (Test-Path -Path ($ProfileListKey + '\' + $sid)) {
				Write-Warn "the ProfileList entry is still there"
				$stayed++
			}
		}
	}
}

# ---- 6. The account ----

if ($kind.Kind -eq 'local' -and -not $kind.Local) {
	Write-Recipe "The local account itself was deleted already, what was left of it is taken"
} elseif ($kind.Kind -eq 'local') {
	$name = $kind.Local.Name
	Write-Recipe ("Deleting the local account " + $name)
	try {
		Remove-LocalUser -SID $sid -ErrorAction Stop
	} catch {
		& net.exe user $name /delete | Out-Null
	}
	$left = $null
	try { $left = Get-LocalUser -SID $sid -ErrorAction Stop } catch { }
	if ($left) {
		Write-Warn ("the local account " + $name + " is still there")
		$stayed++
	}
	# The value that hid the account from the sign-in screen goes with it: a new
	# account created later under the same name would be born hidden
	if ($null -ne (Get-ItemProperty -Path $UserListKey -Name $name -ErrorAction SilentlyContinue)) {
		Remove-ItemProperty -Path $UserListKey -Name $name -ErrorAction SilentlyContinue
		Write-Recipe ("Its value under Winlogon UserList removed")
	}
} else {
	Write-Recipe ("The " + $label + " itself is not deleted: it lives in the " + @{ domain = 'domain'; tenant = 'tenant' }[$kind.Kind] + ", and only what this machine holds of it is taken")
}

# ---- 7. The sign-in screen ----

# What Windows cached of a domain or tenant account at its first sign-in, under
# IdentityStore: Cache\<SID>, and the entries of LogonCache that name the SID.
# This is what keeps a tenant account offered on the sign-in screen once it has
# signed in once, and what lets it sign in with the device offline
$cleared = 0
$cache = $IdentityKey + '\Cache\' + $sid
if (Test-Path -Path $cache) {
	Remove-Item -Path $cache -Recurse -Force -ErrorAction SilentlyContinue
	if (Test-Path -Path $cache) { Write-Warn "IdentityStore\Cache still holds the account"; $stayed++ } else { $cleared++ }
}
foreach ($provider in @(Get-ChildItem -Path ($IdentityKey + '\LogonCache') -ErrorAction SilentlyContinue)) {
	$bySid = $provider.PSPath + '\Sid2Name\' + $sid
	if (Test-Path -Path $bySid) {
		Remove-Item -Path $bySid -Recurse -Force -ErrorAction SilentlyContinue
		$cleared++
	}
	foreach ($entry in @(Get-ChildItem -Path ($provider.PSPath + '\Name2Sid') -ErrorAction SilentlyContinue)) {
		if ((Get-ItemProperty -Path $entry.PSPath -Name Sid -ErrorAction SilentlyContinue).Sid -eq $sid) {
			Remove-Item -Path $entry.PSPath -Recurse -Force -ErrorAction SilentlyContinue
			$cleared++
		}
	}
}
if ($cleared -gt 0) { Write-Recipe "The identity cached at its sign-in removed" }

# The tile of the last account signed in, when it is this one
$last = Get-ItemProperty -Path $LogonUIKey -ErrorAction SilentlyContinue
if ($last -and ($last.LastLoggedOnUserSID -eq $sid -or $last.SelectedUserSID -eq $sid)) {
	foreach ($value in 'LastLoggedOnUser', 'LastLoggedOnSAMUser', 'LastLoggedOnDisplayName', 'LastLoggedOnUserSID', 'SelectedUserSID', 'LastLoggedOnProvider') {
		Remove-ItemProperty -Path $LogonUIKey -Name $value -ErrorAction SilentlyContinue
	}
	Write-Recipe "It is no longer the last account signed in"
}

if ($stayed -gt 0) {
	Write-Warn ("'" + $username + "' was removed in part, " + $stayed + " thing(s) stayed, see above")
	exit 2
}
Write-Recipe ("'" + $username + "' is removed from this machine")
exit 0
