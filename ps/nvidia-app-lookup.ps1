# Resolves the current NVIDIA App installer and prints the result as KEY=VALUE lines, one per
# line, for a batch caller. Same shape as nvidia-driver-lookup.ps1, same reason: the caller
# reads stdout and nothing else.
#
# Why this exists at all. The display driver full package does *not* carry NVIDIA App: field
# report of 2026-08-20, a Wild Cat installed from the quadro-rtx-desktop-notebook package came
# out with the driver and the Control Panel but no NVIDIA App. NVIDIA ships the App as its own
# download, and the Microsoft Store listing (product XP8CLZL93F5Z4P) is not an MSIX: it carries
# no package family name and its installer type is WPM, that is a pointer to the very same
# Win32 setup. So there is nothing to provision the way HPSA9 is provisioned, and nothing that
# installs per user: NVIDIA's own setup is the whole distribution.
#
# There is no evergreen URL here either - every build lives under its own version-numbered
# path, https://us.download.nvidia.com/nvapp/client/<version>/NVIDIA_app_v<version>.exe - but
# the official product page carries the URL of the current build in its markup, so the version
# is read from NVIDIA instead of being hardcoded the way the HPSA9 SoftPaq number is.

$ErrorActionPreference = "Stop"

trap {
	Write-Output "ERROR=$($_.Exception.Message) [line $($_.InvocationInfo.ScriptLineNumber)]"
	exit 1
}

try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

function Write-Fail($message) {
	Write-Output "ERROR=$message"
	exit 1
}

$page = "https://www.nvidia.com/en-us/software/nvidia-app/"

$html = ""
try {
	$html = (Invoke-WebRequest -Uri $page -UseBasicParsing -TimeoutSec 60).Content
} catch {
	Write-Fail "the NVIDIA App product page could not be read: $($_.Exception.Message)"
}

# One shape, taken from the page as NVIDIA writes it. If NVIDIA changes it the recipe has to
# say so out loud rather than fall back to a version frozen in this file, which would install
# an old App for as long as nobody noticed.
$found = [regex]::Matches($html, "https://[a-z0-9.\-/]*download\.nvidia\.com/nvapp/client/([0-9.]+)/NVIDIA_app_v([0-9.]+)\.exe")
if ($found.Count -eq 0) {
	Write-Fail "no NVIDIA App installer URL found on $page : the page layout changed, the URL has to be read by hand"
}

# The page may name more than one build: keep the highest version.
$best = $null
foreach ($m in $found) {
	$candidate = @{ url = $m.Value; version = $m.Groups[2].Value }
	if ($null -eq $best) { $best = $candidate; continue }
	try {
		if ([version]$candidate.version -gt [version]$best.version) { $best = $candidate }
	} catch { }
}

$file = $best.url.Split("/")[-1]
Write-Output "APPVERSION=$($best.version)"
Write-Output "APPFILE=$file"
Write-Output "APPURL=$($best.url)"
exit 0
