# ============================================================
#  remove-teams.ps1
#  Removes every Microsoft Teams this machine carries, in the
#  three shapes Teams has taken over the years:
#    - the current Teams, an MSIX package named MSTeams,
#      installed per user plus the provisioned copy that hands
#      it to the next user who signs in for the first time
#    - the consumer package, MicrosoftTeams, the Chat app
#      Windows 11 ships with
#    - classic Teams, the one the old installer laid down: an
#      MSI named Teams Machine-Wide Installer that drops a
#      per-user Squirrel copy into every profile at logon
#  Removing only the first shape is what leaves a machine with
#  Teams apparently gone and back at the next logon, because the
#  machine-wide installer keeps a Run value that reinstalls it.
#  Exit codes: 0 something was removed, 1 there was nothing to
#  remove, 2 at least one removal failed and the reason is on
#  the lines above. An elevated prompt is required: removal for
#  all users, the provisioned package and msiexec all need it.
# ============================================================

# An unhandled error is named on the console, with the line it came from, before the
# exit code reaches the caller. Every helper of this repository answers the same way.
trap {
	Write-Host ("ERROR     : remove-teams failed: " + $_.Exception.Message + " [line " + $_.InvocationInfo.ScriptLineNumber + "]") -ForegroundColor Red
	exit 2
}

$removed = 0
$failed  = 0

function Write-Recipe([string]$text)  { Write-Host ("RECIPE    : " + $text)  -ForegroundColor Cyan }
function Write-Warn([string]$text)    { Write-Host ("WARNING   : " + $text)  -ForegroundColor Yellow }
function Write-Fail([string]$text)    { Write-Host ("ERROR     : " + $text)  -ForegroundColor Red }

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not (New-Object Security.Principal.WindowsPrincipal $identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
	Write-Fail "this recipe needs an elevated prompt: packages are removed for all users and msiexec is called"
	exit 2
}

# ---- 0. Nothing comes off while it is running ----

foreach ($processName in @('ms-teams', 'Teams')) {
	$running = @(Get-Process -Name $processName -ErrorAction SilentlyContinue)
	if ($running.Count -gt 0) {
		Write-Recipe "Stopping $($running.Count) running $processName process(es)"
		$running | Stop-Process -Force -ErrorAction SilentlyContinue
	}
}

# ---- 1. The MSIX packages, for every user on the machine ----

foreach ($name in @('MSTeams', 'MicrosoftTeams')) {
	$packages = @(Get-AppxPackage -Name $name -AllUsers -ErrorAction SilentlyContinue)
	foreach ($package in $packages) {
		Write-Recipe "Removing the package $($package.Name) $($package.Version) for all users"
		try {
			Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction Stop
			$removed++
		} catch {
			# -AllUsers reached Remove-AppxPackage in Windows 10 1809: on an
			# older build the parameter does not bind and the packages are
			# taken one user at a time instead
			$perUser = $false
			foreach ($user in $package.PackageUserInformation) {
				try {
					Remove-AppxPackage -Package $package.PackageFullName -User $user.UserSecurityId.Sid -ErrorAction Stop
					$perUser = $true
				} catch {
					Write-Fail "$($package.PackageFullName) was not removed for $($user.UserSecurityId.Sid): $($_.Exception.Message)"
				}
			}
			if ($perUser) { $removed++ } else { $failed++ }
		}
	}
}

# ---- 2. The provisioned copy, or the next new user gets Teams back ----

try {
	$provisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop | Where-Object { $_.DisplayName -eq 'MSTeams' -or $_.DisplayName -eq 'MicrosoftTeams' })
} catch {
	Write-Fail "the provisioned packages could not be read: $($_.Exception.Message)"
	$provisioned = @()
	$failed++
}

foreach ($package in $provisioned) {
	Write-Recipe "Removing the provisioned package $($package.DisplayName)"
	try {
		Remove-AppxProvisionedPackage -Online -PackageName $package.PackageName -ErrorAction Stop | Out-Null
		$removed++
	} catch {
		Write-Fail "$($package.PackageName) was not deprovisioned: $($_.Exception.Message)"
		$failed++
	}
}

# ---- 3. Classic Teams: the machine-wide MSI ----

$uninstallRoots = @(
	'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
	'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)

foreach ($root in $uninstallRoots) {
	if (-not (Test-Path $root)) { continue }
	foreach ($key in Get-ChildItem $root -ErrorAction SilentlyContinue) {
		$entry = Get-ItemProperty $key.PSPath -ErrorAction SilentlyContinue
		if (-not $entry -or $entry.DisplayName -notlike 'Teams Machine-Wide Installer*') { continue }

		$productCode = Split-Path $key.PSPath -Leaf
		if ($productCode -notmatch '^\{[0-9A-Fa-f-]{36}\}$') {
			Write-Warn "$($entry.DisplayName) is registered under $productCode, which is not a product code: uninstall it by hand"
			$failed++
			continue
		}

		Write-Recipe "Uninstalling $($entry.DisplayName) $($entry.DisplayVersion), product code $productCode"
		$msi = Start-Process -FilePath 'msiexec.exe' -ArgumentList @('/x', $productCode, '/qn', '/norestart') -Wait -PassThru
		# 1605 is the installer saying the product is not there after all, 3010 a
		# reboot it would like and does not get from here
		if ($msi.ExitCode -eq 0 -or $msi.ExitCode -eq 1605 -or $msi.ExitCode -eq 3010) {
			$removed++
		} else {
			Write-Fail "msiexec returned $($msi.ExitCode) uninstalling $($entry.DisplayName)"
			$failed++
		}
	}
}

# The value that reinstalls classic Teams at every logon. It belongs to the
# machine-wide installer, so once the MSI is gone it is a trap, not a setting
foreach ($run in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run')) {
	if (-not (Test-Path $run)) { continue }
	$values = Get-ItemProperty $run -ErrorAction SilentlyContinue
	foreach ($value in @('TeamsMachineInstaller', 'TeamsMachineUninstallerLocalAppData', 'TeamsMachineUninstallerProgramData')) {
		if ($values -and $null -ne $values.$value) {
			Write-Recipe "Removing the logon value $value from $run"
			try {
				Remove-ItemProperty -Path $run -Name $value -Force -ErrorAction Stop
				$removed++
			} catch {
				Write-Fail "$value was not removed from ${run}: $($_.Exception.Message)"
				$failed++
			}
		}
	}
}

# ---- 4. Classic Teams: the per-user copy in every profile ----

$profilePaths = @()
$profileList = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
if (Test-Path $profileList) {
	$profilePaths = @(
		Get-ChildItem $profileList -ErrorAction SilentlyContinue |
			ForEach-Object { (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).ProfileImagePath } |
			Where-Object { $_ -and (Test-Path $_) }
	)
}

foreach ($profilePath in $profilePaths) {
	$teamsLocal = Join-Path $profilePath 'AppData\Local\Microsoft\Teams'
	$updater    = Join-Path $teamsLocal 'Update.exe'

	if (Test-Path $updater) {
		Write-Recipe "Uninstalling classic Teams from $profilePath"
		try {
			Start-Process -FilePath $updater -ArgumentList @('--uninstall', '-s') -Wait -ErrorAction Stop
			$removed++
		} catch {
			Write-Warn "the uninstaller in $profilePath did not run: $($_.Exception.Message)"
		}
	}

	# The Squirrel uninstaller removes what it installed for the user who runs
	# it, which here is the operator and not the owner of the profile: what is
	# left in the profile is removed by hand
	foreach ($leftover in @($teamsLocal, (Join-Path $profilePath 'AppData\Roaming\Microsoft\Teams'))) {
		if (Test-Path $leftover) {
			Write-Recipe "Removing $leftover"
			try {
				Remove-Item $leftover -Recurse -Force -ErrorAction Stop
				$removed++
			} catch {
				Write-Fail "$leftover was not removed, Teams may still be running for that user: $($_.Exception.Message)"
				$failed++
			}
		}
	}

	$startMenu = Join-Path $profilePath 'AppData\Roaming\Microsoft\Windows\Start Menu\Programs'
	if (Test-Path $startMenu) {
		foreach ($link in @(Get-ChildItem -Path $startMenu -Filter 'Microsoft Teams*.lnk' -ErrorAction SilentlyContinue)) {
			Write-Recipe "Removing the shortcut $($link.FullName)"
			Remove-Item $link.FullName -Force -ErrorAction SilentlyContinue
		}
	}
}

# The uninstall entry each per-user copy registers in its own hive. Only the
# hives of users who are signed in are loaded, and only an entry whose install
# location is gone is removed: this cleans up after step 4, it does not decide
# anything on its own
foreach ($hive in @(Get-ChildItem 'Registry::HKEY_USERS' -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike '*_Classes' })) {
	$key = "Registry::$($hive.Name)\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Teams"
	if (-not (Test-Path $key)) { continue }
	$entry = Get-ItemProperty $key -ErrorAction SilentlyContinue
	if ($entry -and $entry.InstallLocation -and (Test-Path $entry.InstallLocation)) {
		Write-Warn "$key still points at $($entry.InstallLocation), which exists: left alone"
		continue
	}
	Write-Recipe "Removing the stale uninstall entry $key"
	try {
		Remove-Item $key -Recurse -Force -ErrorAction Stop
		$removed++
	} catch {
		Write-Warn "$key was not removed: $($_.Exception.Message)"
	}
}

# ---- 5. What is reported and not touched ----

foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
	if (-not $root) { continue }
	$folder = Join-Path $root 'Teams Installer'
	if (Test-Path $folder) {
		Write-Warn "$folder is still on disk: the machine-wide installer left it behind, look at it before removing it by hand"
	}
}

if ($failed -gt 0) { exit 2 }
if ($removed -eq 0) {
	Write-Recipe "No Teams installation of any kind was found on this machine"
	exit 1
}

Write-Recipe "Teams removed, $removed item(s) in all"
exit 0
