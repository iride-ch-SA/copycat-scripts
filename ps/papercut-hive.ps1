# ============================================================
#  papercut-hive.ps1
#  Installs the PaperCut Hive print client for the user who runs
#  it and links it to that user's email, each step only when it
#  is missing: run it at every sign-in and it does nothing once
#  the client is there and linked.
#
#  WHOSE CONTEXT. The print client is a per user install: it
#  lives in %LOCALAPPDATA%\Programs\PaperCut Hive and the email
#  it is linked to is the UPN of the account signed in. So the
#  script runs as that user, not elevated and never as SYSTEM:
#  under SYSTEM LOCALAPPDATA is the profile of the machine and
#  whoami /upn has no answer, and it refuses to start.
#  The edge node is the per machine half, installed elevated
#  with /systemkey. It is a prerequisite and it is not installed
#  here: without it the script stops.
#
#  WHERE THE KEYS ARE. Region, organisation id, user key and
#  system key belong to the customer, so they are never in this
#  repository, which is public: they are read from a JSON file
#  in C:\Admin\Others, laid there empty by cats prepare
#  PaperCut.Hive and filled in by hand:
#    {
#      "Region":    "<region of the organisation, eu for one>",
#      "OrgId":     "<orgId of the /CURRENTUSER command>",
#      "UserKey":   "<userkey of the /CURRENTUSER command>",
#      "SystemKey": "<systemkey of the edge node command>"
#    }
#  The user signing in has to be able to read that file, so the
#  system key is readable by that user. PaperCut asks for the
#  opposite; it is the price of linking from the user context.
#  No key is ever written to the console.
#
#  THE INSTALLER. C:\Admin\Installers\papercut-hive.exe, a
#  folder every user of the machine can write in. PaperCut
#  publishes no public download - the file comes from the admin
#  console, Edge Mesh, Add edge nodes, Manually deploy edge
#  nodes, Download for Windows - so a copy lives in the CopyCats
#  bucket. If the installer is missing it is downloaded from
#  there into C:\Admin\Installers and left in place, so the next
#  user of the machine finds it. It is downloaded under another
#  name and renamed once complete: a download cut short leaves
#  no truncated installer for the next user to run.
#
#  THE LINK. pc-print-client-service.exe command link-with-email
#  writes data\config\userclient.ident; that file is how this
#  script tells a linked client from one that is not. PaperCut
#  documents that a running client picks the link up only after
#  a restart; in practice the link was seen to take effect
#  without one, so the restart is not done unless -Restart is
#  given, and then it is done the way PaperCut documents it:
#  stop pc-print-client, start pc-print-client.exe.
#
#  Parameters:
#    -Config <path>      the JSON with the keys,
#                        C:\Admin\Others\papercut-hive.json
#    -Installer <path>   the installer,
#                        C:\Admin\Installers\papercut-hive.exe
#    -InstallerUrl <url> where to download it from when it is
#                        missing, the CopyCats bucket
#    -Timeout <seconds>  how long to wait for the client to
#                        appear after the installer, 120
#    -Restart            restart the print client after linking
#
#  Exit codes: 0 installed and linked, whether or not anything
#  had to be done; 1 the edge node is not on this machine; 2 the
#  installation failed; 3 the UPN of the user cannot be read;
#  4 the link failed; 5 the JSON is missing or incomplete; 6 the
#  installer is missing and the download failed; 7 the script
#  runs as SYSTEM; 8 an unexpected error, named on the console.
# ============================================================

[CmdletBinding()]
param(
	[string]$Config = 'C:\Admin\Others\papercut-hive.json',
	[string]$Installer = 'C:\Admin\Installers\papercut-hive.exe',
	[string]$InstallerUrl = 'https://storage.googleapis.com/01931185-232c-77a5-8e67-8751490ebf3e/CopyCats/Admin/Installers/papercut-hive.exe',
	[int]$Timeout = 120,
	[switch]$Restart
)

$ErrorActionPreference = 'Stop'

function Write-Recipe([string]$text) { Write-Host ("RECIPE    : " + $text) -ForegroundColor Cyan }
function Write-Done([string]$text)   { Write-Host ("RECIPE    : " + $text) -ForegroundColor Green }
function Write-Fail([string]$text)   { Write-Host ("ERROR     : " + $text) -ForegroundColor Red }

trap {
	Write-Fail "papercut-hive failed: $($_.Exception.Message) [line $($_.InvocationInfo.ScriptLineNumber)]"
	exit 8
}

$base  = Join-Path $env:LOCALAPPDATA 'Programs\PaperCut Hive'
$svc   = Join-Path $base 'pc-print-client-service.exe'
$ident = Join-Path $base 'data\config\userclient.ident'

# Waits until a file exists, or the time is up
function Wait-File([string]$path, [int]$seconds) {
	$deadline = (Get-Date).AddSeconds($seconds)
	while (-not (Test-Path -LiteralPath $path)) {
		if ((Get-Date) -gt $deadline) { return $false }
		Start-Sleep -Seconds 2
	}
	return $true
}

# 0. Context: the user signing in, never SYSTEM
if ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value -eq 'S-1-5-18') {
	Write-Fail 'this runs as SYSTEM, and the print client is installed and linked per user'
	exit 7
}

# 0. The keys, from the file of the customer
if (-not (Test-Path -LiteralPath $Config)) {
	Write-Fail "$Config is missing: it holds the keys of the customer"
	exit 5
}
$cfg = Get-Content -LiteralPath $Config -Raw | ConvertFrom-Json
$missing = @('Region', 'OrgId', 'UserKey', 'SystemKey') | Where-Object { -not ([string]$cfg.$_).Trim() }
if ($missing) {
	Write-Fail ("$Config has no value for " + ($missing -join ', '))
	exit 5
}
$region    = ([string]$cfg.Region).Trim()
$orgId     = ([string]$cfg.OrgId).Trim()
$userKey   = ([string]$cfg.UserKey).Trim()
$systemKey = ([string]$cfg.SystemKey).Trim()

# 0. The edge node, per machine, installed elevated elsewhere. The file is the
# detection rule PaperCut gives for Intune; the service name is checked as well
$edge = Join-Path $env:ProgramFiles 'PaperCut Hive\pc-edgenode-service.exe'
if (-not (Test-Path -LiteralPath $edge) -and -not (Get-Service -Name 'pc-edgenode-service' -ErrorAction SilentlyContinue)) {
	Write-Fail 'the PaperCut Hive edge node is not on this machine: it is installed elevated, with /systemkey'
	exit 1
}

# 1. The client, when it is missing
if (-not (Test-Path -LiteralPath $svc)) {
	if (-not (Test-Path -LiteralPath $Installer)) {
		Write-Recipe "$Installer is missing: downloading it from the CopyCats bucket"
		$partial = $Installer + '.download'
		try {
			$folder = Split-Path -Parent $Installer
			if (-not (Test-Path -LiteralPath $folder)) { New-Item -ItemType Directory -Path $folder | Out-Null }
			[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
			(New-Object System.Net.WebClient).DownloadFile($InstallerUrl, $partial)
			Move-Item -LiteralPath $partial -Destination $Installer -Force
		} catch {
			Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
			Write-Fail "download failed: $($_.Exception.Message)"
			exit 6
		}
	}

	Write-Recipe 'Installing the PaperCut Hive print client for this user'
	# WaitForExit and not Start-Process -Wait: -Wait waits for every process the
	# installer starts as well, and the print client it starts does not end
	$arguments = "/VERYSILENT /CURRENTUSER /region=$region /userkey=`"$userKey`" /orgId=`"$orgId`""
	# The handle is read before the process ends, or ExitCode comes back empty
	$process = Start-Process -FilePath $Installer -ArgumentList $arguments -PassThru
	$null = $process.Handle
	$process.WaitForExit()
	$code = $process.ExitCode
	if ($code -ne 0) {
		Write-Fail "the installer answered $code"
		exit 2
	}
	if (-not (Wait-File $svc $Timeout)) {
		Write-Fail "the installer ended, and $svc did not appear within $Timeout seconds"
		exit 2
	}
	Write-Done 'PaperCut Hive print client installed'
}

# 2. The link, when it is missing
if (Test-Path -LiteralPath $ident) {
	Write-Done 'PaperCut Hive print client installed and linked, nothing to do'
	exit 0
}

# Native commands run with Continue: under Stop, Windows PowerShell 5.1 turns
# whatever they write to standard error into a terminating error
$ErrorActionPreference = 'Continue'
$upn = (& whoami /upn 2>$null | Out-String).Trim()
$code = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($code -ne 0 -or $upn -notmatch '^[^@\s]+@[^@\s]+$') {
	Write-Fail 'the UPN of this user cannot be read: a local account has none, and the link needs an email'
	exit 3
}

Write-Recipe "Linking the print client to $upn"
$ErrorActionPreference = 'Continue'
& $svc command link-with-email $systemKey $upn $region
$code = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if (-not (Wait-File $ident 30)) {
	Write-Fail "the link failed: link-with-email answered $code and $ident was not written"
	exit 4
}

if ($Restart) {
	Write-Recipe 'Restarting the print client'
	Get-Process -Name 'pc-print-client' -ErrorAction SilentlyContinue | Stop-Process -Force
	Start-Sleep -Seconds 2
	Start-Process -FilePath (Join-Path $base 'pc-print-client.exe')
}

Write-Done "PaperCut Hive print client linked to $upn"
exit 0
