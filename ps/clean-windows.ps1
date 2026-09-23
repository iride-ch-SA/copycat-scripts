# ============================================================
#  clean-windows.ps1
#  Takes the consumer apps off a Windows 11 workstation and
#  sets the Start menu the way a workplace wants it.
#
#  What it does
#    apps    removes every package of the list below for all
#            users, and the provisioned copy that would hand it
#            to the next user who signs in for the first time
#    start   sets the All section of the Start menu to List view
#            (AllAppsViewMode = 2) in the default profile, so
#            every new user gets it, and in every profile
#            already on the machine
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
#  A package
#  Windows marks NonRemovable is reported and left alone.
#
#  -List says what would be removed and changed, and changes
#  nothing.
#
#  Exit codes: 0 something was removed or set (or, with -List,
#  found), 1 there was nothing to do, 2 the run cannot do its
#  work - not Windows 11, a server, no elevation, or a removal
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

# ---- 3. The Start menu, All section in List view, in every profile ----

# The value lives in each user's own hive. A signed-in user's hive is
# already under HKEY_USERS and is written there; any other profile,
# and the default one new users are copied from, is loaded from its
# NTUSER.DAT, written and unloaded. reg.exe does the reading and the
# writing as well as the loading: a key opened through the registry
# provider keeps a handle that makes reg unload fail
$startKey  = 'Software\Microsoft\Windows\CurrentVersion\Start'
$startName = 'AllAppsViewMode'
$startList = 2

function Set-StartView([string]$hiveRoot, [string]$label) {
	$query = & reg.exe query "$hiveRoot\$startKey" /v $startName 2>$null
	if ($LASTEXITCODE -eq 0 -and ($query -match "$startName\s+REG_DWORD\s+0x0*$startList\b")) { return }
	if ($script:List) {
		Write-Recipe "Would set the Start menu to List view for $label"
		$script:changed++
		return
	}
	& reg.exe add "$hiveRoot\$startKey" /v $startName /t REG_DWORD /d $startList /f | Out-Null
	if ($LASTEXITCODE -eq 0) {
		Write-Recipe "Start menu set to List view for $label"
		$script:changed++
	} else {
		Write-Fail "the Start menu view was not written for $label, reg add returned $LASTEXITCODE"
		$script:failed++
	}
}

function Set-StartViewInFile([string]$hiveFile, [string]$label) {
	if (-not (Test-Path $hiveFile)) { return }
	$mount = 'HKU\CatsCleanWindows'
	& reg.exe load $mount $hiveFile 2>&1 | Out-Null
	if ($LASTEXITCODE -ne 0) {
		Write-Warn "the hive of $label could not be loaded, it may be in use: left as it is"
		return
	}
	try {
		Set-StartView $mount $label
	} finally {
		& reg.exe unload $mount 2>&1 | Out-Null
		if ($LASTEXITCODE -ne 0) { Write-Warn "the hive of $label is still mounted as $mount, it goes at the next restart" }
	}
}

# The folder that holds the profiles, C:\Users on a default installation
$usersDir = Split-Path $env:PUBLIC -Parent
Set-StartViewInFile "$usersDir\Default\NTUSER.DAT" 'the default profile, that is every new user'

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
		Set-StartView "HKU\$sid" $profilePath
	} else {
		Set-StartViewInFile "$profilePath\NTUSER.DAT" $profilePath
	}
}

# The Start menu reads the value when it starts: it is restarted so the
# signed-in users see the change, and Windows starts it again on its own
if (-not $List -and $changed -gt 0) {
	Get-Process -Name 'StartMenuExperienceHost' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

if ($failed -gt 0) { exit 2 }
if ($changed -eq 0) {
	Write-Recipe "Nothing to change: no app of the list is here and the Start menu is already in List view"
	exit 1
}

if ($List) { Write-Recipe "$changed change(s) a clean would make" } else { Write-Recipe "$changed change(s) made" }
exit 0
