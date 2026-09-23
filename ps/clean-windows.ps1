# ============================================================
#  clean-windows.ps1
#  Takes the consumer apps off a Windows 11 workstation and
#  sets the Start menu the way a workplace wants it.
#
#  What it does
#    apps     removes every package of the list below for all
#             users, and the provisioned copy that would hand it
#             to the next user who signs in for the first time
#    user     writes the per-user settings of the list below in
#             the default profile, so every new user gets them,
#             and in every profile already on the machine:
#               - the All section of the Start menu in List view
#               - no promoted app installed behind the user's back
#               - no Bing web results in the Start menu search
#               - no recommendations, tips or setup nags in Start,
#                 Settings and on the lock screen
#               - no advertising ID, no tailored experiences
#               - no game recording
#    machine  writes the machine settings of the list below:
#               - fast startup off, so a shutdown is a real one
#               - diagnostic data at Required, advertising ID
#                 off by policy
#               - game recording off by policy
#
#  It runs on Windows 11 only, and never on a server: the check
#  reads InstallationType and CurrentBuildNumber from the
#  registry, because ProductName still says Windows 10 on
#  Windows 11 and the Server editions carry the same packages
#  under a different contract.
#
#  What it does NOT do, on purpose: Microsoft Store, Edge,
#  OneDrive, Teams (cats clean Microsoft.Teams), the frameworks
#  other apps depend on (Xbox Identity Provider, Xbox TCUI,
#  Xbox Speech To Text, and Get Help, which the troubleshooters
#  open) and anything a user may reasonably work with (Photos,
#  Snipping Tool, Calculator, Notepad, Paint, Sticky Notes).
#  A package Windows marks NonRemovable is reported and left
#  alone. No setting is written under Software\Policies of the
#  user hives: a policy there is what sends the Start menu back
#  to Category view at a Group Policy refresh.
#
#  -List says what would be removed and changed, and changes
#  nothing.
#
#  Exit codes: 0 something was removed or set (or, with -List,
#  found), 1 there was nothing to do, 2 the run cannot do its
#  work - not Windows 11, a server, no elevation, or a change
#  that failed.
# ============================================================

[CmdletBinding()]
param(
	[switch]$List
)

# An unhandled error is named on the console, with the line it came from, before the
# exit code reaches the caller. Every helper of this repository answers the same way.
trap {
	Write-Host ("ERROR     : clean-windows failed: " + $_.Exception.Message + " [line " + $_.InvocationInfo.ScriptLineNumber + "]") -ForegroundColor Red
	exit 2
}

function Write-Recipe([string]$text) { Write-Host ("RECIPE    : " + $text) -ForegroundColor Cyan }
function Write-Warn([string]$text)   { Write-Host ("WARNING   : " + $text) -ForegroundColor Yellow }
function Write-Fail([string]$text)   { Write-Host ("ERROR     : " + $text) -ForegroundColor Red }

# The packages that come off. Names, not wildcards: a pattern that
# matches today's consumer app may match tomorrow's system component
$apps = @(
	'MicrosoftCorporationII.QuickAssist',       # Quick Assist, remote support is TeamViewerQS
	'Microsoft.BingSearch',                     # Microsoft Bing
	'Microsoft.BingNews',                       # News
	'Microsoft.BingWeather',                    # Weather
	'Microsoft.News',
	'Microsoft.MicrosoftSolitaireCollection',   # Solitaire & Casual Games
	'Microsoft.GamingApp',                      # Xbox
	'Microsoft.XboxApp',                        # Xbox Console Companion
	'Microsoft.XboxGamingOverlay',              # Game Bar
	'Microsoft.XboxGameOverlay',
	'Clipchamp.Clipchamp',
	'Microsoft.549981C3F5F10',                  # Cortana
	'Microsoft.Getstarted',                     # Tips
	'Microsoft.WindowsFeedbackHub',
	'Microsoft.ZuneVideo',                      # Films & TV
	'MicrosoftCorporationII.MicrosoftFamily',   # Family Safety
	'Microsoft.MixedReality.Portal',
	'Microsoft.Microsoft3DViewer',
	'Microsoft.SkypeApp'
)

$changed = 0
$failed  = 0

# ---- 0. Where this may run ----

$currentVersion = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
$build = 0
[void][int]::TryParse([string]$currentVersion.CurrentBuildNumber, [ref]$build)

if ($currentVersion.InstallationType -ne 'Client') {
	Write-Fail "this is a $($currentVersion.InstallationType) installation of $($currentVersion.ProductName): the recipe runs on Windows 11 workstations only"
	exit 2
}
if ($build -lt 22000) {
	Write-Fail "build $build is Windows 10 or older: the recipe runs on Windows 11 only, build 22000 or later"
	exit 2
}
Write-Recipe "Windows 11 $($currentVersion.EditionID) $($currentVersion.DisplayVersion), build $build"

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not (New-Object Security.Principal.WindowsPrincipal $identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
	Write-Fail "this recipe needs an elevated prompt: packages are removed for all users and other profiles are written"
	exit 2
}

if ($List) { Write-Recipe "Listing what a clean would change on this machine, nothing is changed" }

# ---- 1. The packages, for every user on the machine ----

foreach ($name in $apps) {
	foreach ($package in @(Get-AppxPackage -Name $name -AllUsers -ErrorAction SilentlyContinue)) {
		if ($package.NonRemovable) {
			Write-Warn "$($package.Name) is marked NonRemovable by Windows: left alone"
			continue
		}
		if ($List) {
			Write-Recipe "Would remove the package $($package.Name) $($package.Version) for all users"
			$changed++
			continue
		}
		Write-Recipe "Removing the package $($package.Name) $($package.Version) for all users"
		try {
			Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction Stop
			$changed++
		} catch {
			# The package may be registered for a user whose removal Windows
			# refuses in one go: it is then taken one user at a time
			$perUser = $false
			foreach ($user in $package.PackageUserInformation) {
				try {
					Remove-AppxPackage -Package $package.PackageFullName -User $user.UserSecurityId.Sid -ErrorAction Stop
					$perUser = $true
				} catch {
					Write-Fail "$($package.PackageFullName) was not removed for $($user.UserSecurityId.Sid): $($_.Exception.Message)"
				}
			}
			if ($perUser) { $changed++ } else { $failed++ }
		}
	}
}

# ---- 2. The provisioned copies, or the next new user gets them back ----

try {
	$provisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop | Where-Object { $apps -contains $_.DisplayName })
} catch {
	Write-Fail "the provisioned packages could not be read: $($_.Exception.Message)"
	$provisioned = @()
	$failed++
}

foreach ($package in $provisioned) {
	if ($List) {
		Write-Recipe "Would remove the provisioned package $($package.DisplayName)"
		$changed++
		continue
	}
	Write-Recipe "Removing the provisioned package $($package.DisplayName)"
	try {
		Remove-AppxProvisionedPackage -Online -PackageName $package.PackageName -ErrorAction Stop | Out-Null
		$changed++
	} catch {
		Write-Fail "$($package.PackageName) was not deprovisioned: $($_.Exception.Message)"
		$failed++
	}
}

# ---- 3. The per-user settings, in every profile ----

# Every value lives in each user's own hive, under the path given here
# relative to it. Only REG_DWORD values
$userValues = @(
	# The All section of the Start menu in List view: 0 Category, 1 Grid, 2 List
	@('Software\Microsoft\Windows\CurrentVersion\Start', 'AllAppsViewMode', 2),
	# No promoted app installed behind the user's back: these are the switches
	# that bring the consumer apps removed above back in through the Start menu
	@('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SilentInstalledAppsEnabled', 0),
	@('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'PreInstalledAppsEnabled', 0),
	@('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'PreInstalledAppsEverEnabled', 0),
	@('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'OemPreInstalledAppsEnabled', 0),
	@('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SystemPaneSuggestionsEnabled', 0),
	@('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SubscribedContent-338388Enabled', 0),
	# No Bing web results in the Start menu search. The policy that does the same,
	# DisableSearchBoxSuggestions, lives under Software\Policies and is left alone
	@('Software\Microsoft\Windows\CurrentVersion\Search', 'BingSearchEnabled', 0),
	# Start: no recommendations of tips, shortcuts and new apps, no account notifications
	@('Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced', 'Start_IrisRecommendations', 0),
	@('Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced', 'Start_AccountNotifications', 0),
	# No "get even more out of Windows" after an update, no welcome experience, no tips as you use Windows
	@('Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement', 'ScoobeSystemSettingEnabled', 0),
	@('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SubscribedContent-310093Enabled', 0),
	@('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SubscribedContent-338389Enabled', 0),
	@('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SoftLandingEnabled', 0),
	# No suggested content in Settings
	@('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SubscribedContent-338393Enabled', 0),
	@('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SubscribedContent-353694Enabled', 0),
	@('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SubscribedContent-353696Enabled', 0),
	# Lock screen: the picture stays, the fun facts and tips over it go
	@('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SubscribedContent-338387Enabled', 0),
	@('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'RotatingLockScreenOverlayEnabled', 0),
	# Privacy: no advertising ID for apps, no tailored experiences from diagnostic data
	@('Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo', 'Enabled', 0),
	@('Software\Microsoft\Windows\CurrentVersion\Privacy', 'TailoredExperiencesWithDiagnosticDataEnabled', 0),
	# No game recording
	@('System\GameConfigStore', 'GameDVR_Enabled', 0),
	@('Software\Microsoft\Windows\CurrentVersion\GameDVR', 'AppCaptureEnabled', 0)
)

# The machine settings, under HKLM
$machineValues = @(
	# Fast startup off: a shutdown is a real one, and a driver or an update
	# that waits for a restart does not wait for a restart that never comes
	@('SYSTEM\CurrentControlSet\Control\Session Manager\Power', 'HiberbootEnabled', 0),
	# Diagnostic data at Required, the lowest level Pro honours; 0 means
	# Security only and is taken as Required on anything but Enterprise and Education
	@('SOFTWARE\Policies\Microsoft\Windows\DataCollection', 'AllowTelemetry', 1),
	@('SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo', 'DisabledByGroupPolicy', 1),
	@('SOFTWARE\Policies\Microsoft\Windows\GameDVR', 'AllowGameDVR', 0)
)

# reg.exe does the reading and the writing as well as the loading of the
# hives: a key opened through the registry provider keeps a handle that
# makes reg unload fail. Answers how many values were written - with
# -List, how many would be - and counts the failures itself
function Set-Values([string]$root, [object[]]$values) {
	$count = 0
	foreach ($entry in $values) {
		$key = "$root\$($entry[0])"
		$name = $entry[1]
		$value = $entry[2]
		$query = & reg.exe query $key /v $name 2>$null
		$hex = '{0:x}' -f $value
		if ($LASTEXITCODE -eq 0 -and ($query -match ('\s' + [regex]::Escape($name) + '\s+REG_DWORD\s+0x0*' + $hex + '\s*$'))) { continue }
		if ($script:List) { $count++; continue }
		& reg.exe add $key /v $name /t REG_DWORD /d $value /f 2>&1 | Out-Null
		if ($LASTEXITCODE -eq 0) {
			$count++
		} else {
			Write-Fail "$key\$name was not written, reg add returned $LASTEXITCODE"
			$script:failed++
		}
	}
	return $count
}

function Set-UserValues([string]$hiveRoot, [string]$label) {
	$count = Set-Values $hiveRoot $script:userValues
	if ($count -eq 0) { return }
	$script:changed += $count
	if ($script:List) { Write-Recipe "Would write $count setting(s) for $label" } else { Write-Recipe "$count setting(s) written for $label" }
}

# A signed-in user's hive is already under HKEY_USERS and is written
# there; any other profile, and the default one new users are copied
# from, is loaded from its NTUSER.DAT, written and unloaded
function Set-UserValuesInFile([string]$hiveFile, [string]$label) {
	if (-not (Test-Path $hiveFile)) { return }
	$mount = 'HKU\CatsCleanWindows'
	& reg.exe load $mount $hiveFile 2>&1 | Out-Null
	if ($LASTEXITCODE -ne 0) {
		Write-Warn "the hive of $label could not be loaded, it may be in use: left as it is"
		return
	}
	try {
		Set-UserValues $mount $label
	} finally {
		& reg.exe unload $mount 2>&1 | Out-Null
		if ($LASTEXITCODE -ne 0) { Write-Warn "the hive of $label is still mounted as $mount, it goes at the next restart" }
	}
}

# The folder that holds the profiles, C:\Users on a default installation
$usersDir = Split-Path $env:PUBLIC -Parent
Set-UserValuesInFile "$usersDir\Default\NTUSER.DAT" 'the default profile, that is every new user'

$loaded = @(Get-ChildItem 'Registry::HKEY_USERS' -ErrorAction SilentlyContinue | ForEach-Object { $_.PSChildName })
$profileList = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
foreach ($key in @(Get-ChildItem $profileList -ErrorAction SilentlyContinue)) {
	$sid = $key.PSChildName
	# S-1-5-21 are local and domain accounts, S-1-12-1 Entra accounts; the
	# service profiles under S-1-5-18/19/20 have no Start menu to speak of
	if ($sid -notlike 'S-1-5-21-*' -and $sid -notlike 'S-1-12-1-*') { continue }
	$profilePath = (Get-ItemProperty $key.PSPath -ErrorAction SilentlyContinue).ProfileImagePath
	if (-not $profilePath) { continue }
	if ($loaded -contains $sid) {
		Set-UserValues "HKU\$sid" $profilePath
	} else {
		Set-UserValuesInFile "$profilePath\NTUSER.DAT" $profilePath
	}
}

# ---- 4. The machine settings ----

$machineCount = Set-Values 'HKLM' $machineValues
if ($machineCount -gt 0) {
	$changed += $machineCount
	if ($List) { Write-Recipe "Would write $machineCount machine setting(s)" } else { Write-Recipe "$machineCount machine setting(s) written" }
}

# The Start menu reads its view when it starts: it is restarted so the
# signed-in users see the change, and Windows starts it again on its own.
# The other settings take effect at the next sign-in, fast startup at the
# next shutdown
if (-not $List -and $changed -gt 0) {
	Get-Process -Name 'StartMenuExperienceHost' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

if ($failed -gt 0) { exit 2 }
if ($changed -eq 0) {
	Write-Recipe "Nothing to change: no app of the list is here and every setting is already in place"
	exit 1
}

if ($List) { Write-Recipe "$changed change(s) a clean would make" } else { Write-Recipe "$changed change(s) made" }
exit 0
