param (
	[Alias("n")]
	[string]$Name = "",
	[Alias("p")]
	[int]$Psid = 0
)

# Resolves the NVIDIA display driver full package for the GPU physically present in this
# machine and prints the result as KEY=VALUE lines, one per line, for a batch caller.
#
# How it works, and why this way. NVIDIA does not publish an evergreen URL for "the latest
# driver": every package lives under a version-numbered path. The driver lookup service
# behind the nvidia.com download page does answer that question, and it answers it with the
# download URL itself, so the URL is never built here - it is read from NVIDIA.
#
#   https://gfwsl.geforce.com/services_toolkit/services/com/nvidia/services/AjaxDriverService.php
#       ?func=DriverManualLookup&psid=<series>&pfid=<model>&osID=<os>&dch=1...
#
# psid is the product series, pfid the single model. pfid may be left empty: the service then
# answers for the series, which is what we want, because one package covers a whole family -
# a single quadro-rtx-desktop-notebook file serves every current professional GPU, desktop and
# notebook alike, and a single desktop/notebook file serves the GeForce line. pfid is still
# resolved when possible, so that an older GPU gets the branch that still supports it.
#
# Verified against the service on 2026-08-20: series 132, 134, 122, 124, 109 and 116 all
# answer 596.86 quadro-rtx-desktop-notebook, GeForce series answer 610.88 desktop or notebook.
#
# -Name overrides the detected GPU name, -Psid forces the series: both exist for the machine
# whose adapter Windows cannot name yet, which is exactly the machine that needs a driver.

$ErrorActionPreference = "Stop"
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

# The series table. Order matters: a professional board is matched before the GeForce pattern
# that would also fit its number, so that "RTX 4000 Ada Generation" is not read as a GeForce
# RTX 40. d = desktop series id, n = notebook series id.
$series = @(
	@{ re = "RTX\s*PRO";                                          d = 132; n = 134; label = "NVIDIA RTX PRO" }
	@{ re = "Quadro\s*RTX";                                       d = 109; n = 116; label = "Quadro RTX" }
	@{ re = "RTX\s*A\d+|RTX\s*\d+\s*Ada|RTX\s*\d+\s*Blackwell";   d = 122; n = 124; label = "NVIDIA RTX" }
	@{ re = "\bT(400|500|600|1000|1200|2000)\b";                  d = 122; n = 124; label = "NVIDIA T Series" }
	@{ re = "Quadro";                                             d = 73;  n = 74;  label = "Quadro" }
	@{ re = "RTX\s*5\d{2}\b|RTX\s*5\d{3}";                        d = 131; n = 133; label = "GeForce RTX 50" }
	@{ re = "RTX\s*4\d{2}\b|RTX\s*4\d{3}";                        d = 127; n = 129; label = "GeForce RTX 40" }
	@{ re = "RTX\s*3\d{2}\b|RTX\s*3\d{3}";                        d = 120; n = 123; label = "GeForce RTX 30" }
	@{ re = "RTX\s*2\d{2}\b|RTX\s*2\d{3}";                        d = 107; n = 111; label = "GeForce RTX 20" }
	@{ re = "GTX\s*16\d{2}|GTX\s*1650|GTX\s*1660";                d = 112; n = 115; label = "GeForce GTX 16" }
	@{ re = "GTX\s*10\d{2}|GT\s*10\d{2}";                         d = 101; n = 102; label = "GeForce 10" }
	@{ re = "MX5\d{2}";                                           d = 125; n = 125; label = "GeForce MX500" }
	@{ re = "MX4\d{2}";                                           d = 121; n = 121; label = "GeForce MX400" }
	@{ re = "MX3\d{2}";                                           d = 117; n = 117; label = "GeForce MX300" }
	@{ re = "MX2\d{2}";                                           d = 113; n = 113; label = "GeForce MX200" }
	@{ re = "MX1\d{2}";                                           d = 104; n = 104; label = "GeForce MX100" }
)

function Write-Fail($message) {
	Write-Output "ERROR=$message"
	exit 1
}

# 1. The GPU. Win32_VideoController names the adapter only when a driver already claims it,
# so a machine running on the Microsoft basic display adapter falls back to the PCI device,
# which is present with or without a driver.
$gpu = $Name.Trim()
if ($gpu -eq "") {
	$found = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
		Where-Object { $_.Name -match "NVIDIA" -and $_.Name -notmatch "nForce" })
	if ($found.Count -gt 0) { $gpu = $found[0].Name.Trim() }
}
if ($gpu -eq "") {
	$pnp = @(Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue |
		Where-Object { $_.PNPDeviceID -like "PCI\VEN_10DE*" -and $_.PNPClass -eq "Display" })
	if ($pnp.Count -gt 0) { $gpu = $pnp[0].Name.Trim() }
	if ($gpu -ne "" -and $gpu -notmatch "NVIDIA|GeForce|Quadro|RTX") {
		Write-Fail "an NVIDIA PCI display device is present but Windows names it '$gpu': pass the model, e.g. cats install nvidia ""NVIDIA RTX PRO 2000 Blackwell"""
	}
}
if ($gpu -eq "") { Write-Fail "no NVIDIA display adapter found on this machine" }
Write-Output "GPU=$gpu"

# 2. Desktop or notebook. The GPU name carries it when NVIDIA brands it so; otherwise the
# chassis decides. Immaterial for professional boards - one package covers both - and decisive
# for GeForce, which ships two.
$laptop = $false
if ($gpu -match "Laptop|Mobile|Max-Q|\bMX\d") { $laptop = $true }
else {
	try {
		$types = @((Get-CimInstance Win32_SystemEnclosure).ChassisTypes)
		foreach ($t in $types) { if (@(8,9,10,11,12,14,18,21,30,31,32) -contains [int]$t) { $laptop = $true } }
	} catch { }
}
Write-Output ("FORM=" + $(if ($laptop) { "notebook" } else { "desktop" }))

# 3. The series
$label = "forced"
if ($Psid -eq 0) {
	foreach ($s in $series) {
		if ($gpu -match $s.re) {
			$Psid = $(if ($laptop) { $s.n } else { $s.d })
			$label = $s.label
			break
		}
	}
}
if ($Psid -eq 0) {
	Write-Fail "GPU '$gpu' matches no known NVIDIA series: add it to ps\nvidia-driver-lookup.ps1 or force the series with -Psid"
}
Write-Output "SERIES=$label"
Write-Output "PSID=$Psid"

# 4. The model id, best effort. The service answers for the series without it, so a miss here
# is not a failure: it only means the answer is the series' current driver rather than the one
# picked for this exact board.
$pfid = ""
$normalise = {
	param($s)
	($s -replace "NVIDIA", "" -replace "Generation", "" -replace "GPU", "" -replace "[^A-Za-z0-9]", "").ToUpper()
}
try {
	$listUrl = "https://www.nvidia.com/Download/API/lookupValueSearch.aspx?TypeID=3&ParentID=$Psid"
	$xml = [xml]((Invoke-WebRequest -UseBasicParsing -TimeoutSec 30 $listUrl).Content)
	$target = & $normalise $gpu
	foreach ($lv in $xml.LookupValueSearch.LookupValues.LookupValue) {
		if ((& $normalise $lv.Name) -eq $target) { $pfid = $lv.Value; break }
	}
} catch { }
Write-Output "PFID=$pfid"

# 5. Windows 11 and Windows 10 64-bit are two ids for one package, but the service wants one
$osid = 57
try { if ([int]((Get-CimInstance Win32_OperatingSystem).BuildNumber) -ge 22000) { $osid = 135 } } catch { }
Write-Output "OSID=$osid"

# 6. The driver itself. dch=1 selects the DCH package, the only kind shipped for Windows 10
# 1809 and later; driver-only and network-installer variants are rejected because the recipe
# exists to bring the full package, NVIDIA App and Control Panel included.
$lookup = "https://gfwsl.geforce.com/services_toolkit/services/com/nvidia/services/AjaxDriverService.php" +
	"?func=DriverManualLookup&psid=$Psid&pfid=$pfid&osID=$osid&languageCode=1033&beta=null&isWHQL=1" +
	"&dltype=-1&dch=1&upCRD=null&qnf=0&sort1=0&numberOfResults=10"
try {
	$answer = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 60 $lookup).Content | ConvertFrom-Json
} catch {
	Write-Fail "the NVIDIA driver lookup service could not be reached: $($_.Exception.Message)"
}

$candidates = @()
foreach ($entry in @($answer.IDS)) {
	$info = $entry.downloadInfo
	if (-not $info) { continue }
	if (-not $info.DownloadURL) { continue }
	if ($info.DownloadURL -match "driver-only|netinst|nsd") { continue }
	$candidates += $info
}
if ($candidates.Count -eq 0) {
	Write-Fail "the NVIDIA lookup service returned no full package for series $Psid: this GPU may be served by a legacy branch only"
}

# The service answers newest first, but the order is its choice and not a contract: sort by
# version and keep the top one, falling back to the given order if a version does not parse.
$best = $candidates[0]
try {
	$best = $candidates | Sort-Object { [version]($_.Version) } -Descending | Select-Object -First 1
} catch { }

$file = $best.DownloadURL.Split("/")[-1]
Write-Output "VERSION=$($best.Version)"
Write-Output "RELEASED=$($best.ReleaseDateTime)"
Write-Output "SIZE=$($best.DownloadURLFileSize)"
Write-Output "FILE=$file"
Write-Output "URL=$($best.DownloadURL)"
exit 0
