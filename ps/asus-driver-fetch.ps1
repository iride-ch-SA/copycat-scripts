# ============================================================
#  asus-driver-fetch.ps1
#  Fills the local driver library for an ASUS NUC from the ASUS
#  download catalogue, so that cats install Drivers has
#  something to match the devices of this machine against.
#
#  Four steps, each of which can stop the run with its own exit
#  code, because each of them can fail for a reason an operator
#  has to read:
#    1. is this an ASUS board at all, and what is its model? The
#       SMBIOS board product is the model the catalogue is keyed
#       by - verified 2026-09-21: Win32_BaseBoard.Product says
#       NUC15CRBC5 and the catalogue answers to that string as
#       it is. It is not shortened and not translated into the
#       kit name: the kit is a *different* catalogue
#    2. what does this machine still need? A device Windows
#       reports as ERROR or UNKNOWN is a candidate, and its PnP
#       class picks the catalogue groups worth fetching. A
#       device with no class, or one this map does not know,
#       widens the fetch to every driver group rather than
#       narrowing it
#    3. what is not already here? A package whose marker file
#       carries the same sha256 is not downloaded again
#    4. download, verify the sha256 the catalogue publishes,
#       unpack. The .inf files land under the library folder,
#       which is the only form cats install Drivers can install
#       unattended; an installer .exe inside the archive is left
#       for the operator, as it already is for every other
#       package in that folder
#
#  The device test is deliberately wider than the one in
#  driver-scan.ps1, which weighs problem codes one by one. It
#  can afford to be: a false positive here costs a download, a
#  false positive there would install a driver at a device that
#  did not ask for one.
#
#  The catalogue endpoint is not documented by ASUS. It is what
#  the ASUS support site itself calls, it answers without
#  credentials, and it may change without notice - which is why
#  every failure below names the model and the URL instead of
#  just reporting that something went wrong.
#
#  Parameters:
#    -Path <folder>   the driver library, C:\Admin\Drivers by
#                     default - the same folder cats install
#                     Drivers reads. ASUS packages go in the
#                     ASUS subfolder of it
#    -Model <sku>     override the model read from SMBIOS, for
#                     the machine whose board reports a name the
#                     catalogue does not know
#    -OsId <n>        52 is Windows 11 64-bit, and is required:
#                     omitted, the endpoint answers with a null
#                     result rather than an error
#    -MaxSizeMB <n>   skip anything larger, naming it and its
#                     URL. 1024 by default: this catalogue holds
#                     single packages of 1.6 GB, and a posa does
#                     not wait for them by accident
#    -InfPack         also take the family INF driver pack, the
#                     one-click package of a whole NUC family.
#                     Over a gigabyte, and it also needs
#                     -MaxSizeMB raised
#    -All             every group and every device, whether or
#                     not a device is missing anything - the
#                     form for preparing a machine that is going
#                     to be imaged
#    -Check           report what would be fetched, fetch nothing
#    -Force           fetch again what is already there
#
#  Exit codes: 0 at least one package was added to the library,
#  1 there was nothing to add - either no device needs a driver
#  or everything relevant is already in the library, 2 something
#  failed and the reason is on the lines above, 3 this machine
#  is not an ASUS board or its model is not in the catalogue,
#  which is the case where an operator has to go and fetch the
#  package by hand.
# ============================================================

[CmdletBinding()]
param(
	[string]$Path = 'C:\Admin\Drivers',
	[string]$Model = '',
	[int]$OsId = 52,
	[int]$MaxSizeMB = 1024,
	[switch]$InfPack,
	[switch]$All,
	[switch]$Check,
	[switch]$Force
)

$ErrorActionPreference = 'Stop'

function Write-Recipe([string]$text) { Write-Host ("RECIPE    : " + $text) -ForegroundColor Cyan }
function Write-Warn([string]$text)   { Write-Host ("WARNING   : " + $text) -ForegroundColor Yellow }
function Write-Fail([string]$text)   { Write-Host ("ERROR     : " + $text) -ForegroundColor Red }
function Write-Plain([string]$text)  { Write-Host ("            " + $text) }

function Expand-Zip([string]$archive, [string]$destination) {
	try {
		Expand-Archive -LiteralPath $archive -DestinationPath $destination -Force -ErrorAction Stop
	} catch {
		# Expand-Archive is the readable form and fails on some large archives; the
		# framework call underneath it does not
		Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
		[IO.Compression.ZipFile]::ExtractToDirectory($archive, $destination)
	}
}

trap {
	Write-Fail "asus-driver-fetch failed: $($_.Exception.Message) [line $($_.InvocationInfo.ScriptLineNumber)]"
	exit 2
}

# Windows PowerShell 5.1 still defaults to protocols dlcdnets.asus.com will not talk
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

$catalogueBase = 'https://www.asus.com/support/api/product.asmx/GetPDDrivers'

# A group that holds applications rather than drivers. Fetched only with -All: the Store
# links and appx preinstall kits in it are not something pnputil can do anything with.
$notDriverGroups = @('Software and Utility')

# PnP class -> the catalogue groups worth fetching for it. A class that is not in this map,
# and the empty class an unknown device reports, mean "fetch every driver group": at that
# point the machine cannot say what it is missing, and the catalogue is the cheaper guess.
$classToGroups = @{
	'NET'            = @('LAN', 'Wireless')
	'BLUETOOTH'      = @('Bluetooth')
	'DISPLAY'        = @('VGA Drivers')
	'MEDIA'          = @('Audio')
	'AUDIOENDPOINT'  = @('Audio')
	'USB'            = @('USB')
	'USBDEVICE'      = @('USB')
	'SDHOST'         = @('Chipset')
	'SYSTEM'         = @('Chipset', 'Driver Package')
}

# ---- 1. Which machine is this ----

if ([string]::IsNullOrWhiteSpace($Model)) {
	$board = $null
	try {
		$board = Get-CimInstance -ClassName Win32_BaseBoard -ErrorAction Stop
	} catch {
		Write-Fail "the board could not be read over CIM: $($_.Exception.Message)"
		exit 2
	}
	$maker = ''
	if ($null -ne $board -and $null -ne $board.Manufacturer) { $maker = [string]$board.Manufacturer }
	if ($maker -notmatch '(?i)asus') {
		Write-Fail "this board reports '$maker' as its manufacturer, so the ASUS catalogue has nothing for it"
		Write-Plain "cats install Drivers still works on whatever is already in $Path"
		exit 3
	}
	if ($null -ne $board -and -not [string]::IsNullOrWhiteSpace($board.Product)) { $Model = ([string]$board.Product).Trim() }
	if ([string]::IsNullOrWhiteSpace($Model)) {
		Write-Fail "the board is an ASUS one but reports no product name, so there is no model to ask the catalogue for"
		exit 3
	}
	Write-Recipe "ASUS board, model $Model (read from SMBIOS)"
} else {
	Write-Recipe "Model $Model (given on the command line, not read from the machine)"
}

# ---- 2. What does this machine still need ----

$wantedGroups = @()
$fetchEverything = $false

if ($All) {
	Write-Recipe "Taking the whole catalogue, whatever this machine is missing"
	$fetchEverything = $true
} else {
	$broken = @()
	try {
		$broken = @(Get-PnpDevice -PresentOnly -ErrorAction Stop | Where-Object { $_.Status -eq 'ERROR' -or $_.Status -eq 'UNKNOWN' })
	} catch {
		Write-Warn "the devices could not be enumerated ($($_.Exception.Message)), so the whole catalogue is considered"
		$fetchEverything = $true
	}

	if (-not $fetchEverything) {
		if ($broken.Count -eq 0) {
			Write-Recipe "No device on this machine is missing a driver, so there is nothing to fetch"
			Write-Plain "use 'cats prepare Drivers all' to fill the library anyway, before imaging or before a device is plugged in"
			exit 1
		}
		Write-Warn "$($broken.Count) device(s) have no working driver:"
		foreach ($device in $broken) {
			$name = $device.FriendlyName
			if ([string]::IsNullOrWhiteSpace($name)) { $name = $device.InstanceId }
			$class = ''
			if ($null -ne $device.Class) { $class = ([string]$device.Class).Trim().ToUpperInvariant() }
			$label = if ($class) { $class } else { 'no class' }
			Write-Plain "$name - $label"
			if ($class -and $classToGroups.ContainsKey($class)) {
				$wantedGroups += $classToGroups[$class]
			} else {
				# This machine cannot say what this device is. Narrowing here is how a posa
				# ends with a device still unknown and a catalogue that had its driver.
				$fetchEverything = $true
			}
		}
		$wantedGroups = @($wantedGroups | Select-Object -Unique)
		if ($fetchEverything) {
			Write-Recipe "At least one device does not say what it is, so every driver group is considered"
		} else {
			Write-Recipe "Groups to consider: $($wantedGroups -join ', ')"
		}
	}
}

# ---- 3. What does the catalogue have ----

$url = "$catalogueBase" + "?website=global&model=" + [uri]::EscapeDataString($Model) + "&osid=$OsId"
Write-Recipe "Asking the ASUS catalogue for $Model"

$catalogue = $null
try {
	$response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop
	$catalogue = $response.Content | ConvertFrom-Json
} catch {
	Write-Fail "the ASUS catalogue could not be read: $($_.Exception.Message)"
	Write-Plain $url
	exit 2
}

# A model the catalogue does not know does not answer with an error: it answers with a null
# result. Verified 2026-09-21 - NUC15CRB, the model above cut short, answers exactly this.
if ($null -eq $catalogue -or $null -eq $catalogue.Result -or $null -eq $catalogue.Result.Obj) {
	$status = if ($null -ne $catalogue -and $catalogue.Status) { $catalogue.Status } else { 'no status' }
	Write-Fail "the ASUS catalogue has no entry for model $Model (status: $status)"
	Write-Plain "the model is taken from SMBIOS and is not guessed: if ASUS lists this machine under another name,"
	Write-Plain "run cats prepare Drivers with that name, as in: cats prepare Drivers model NUC15CRKC5"
	exit 3
}

$candidates = @()
$skippedBySize = @()
$skippedGroups = 0

foreach ($group in @($catalogue.Result.Obj)) {
	$groupName = ''
	if ($null -ne $group.Name) { $groupName = ([string]$group.Name).Trim() }

	if (-not $All -and ($notDriverGroups -contains $groupName)) { $skippedGroups++; continue }
	if (-not $fetchEverything -and -not $All -and -not ($wantedGroups -contains $groupName)) { $skippedGroups++; continue }

	foreach ($file in @($group.Files)) {
		$title = [string]$file.Title
		$link = ''
		if ($null -ne $file.DownloadUrl -and $null -ne $file.DownloadUrl.Global) { $link = [string]$file.DownloadUrl.Global }

		# MyASUS and the like are listed with a Microsoft Store link instead of a file
		if ([string]::IsNullOrWhiteSpace($link) -or $link -notmatch '(?i)\.zip(\?|$)') { continue }

		# The family INF pack is a package of the whole family, over a gigabyte, and it is
		# not what fills a library for one machine. Taken only when it is asked for.
		if ($title -match '(?i)INF\s*(Driver\s*)?Pack' -and -not $InfPack) {
			Write-Recipe "Leaving the family INF pack out: $title ($($file.FileSize))"
			Write-Plain "cats prepare Drivers infpack max 2048   takes it instead"
			continue
		}

		$sizeMB = 0.0
		if ($file.FileSize -match '(?i)^\s*([\d.]+)\s*(KB|MB|GB)') {
			$value = [double]$matches[1]
			switch ($matches[2].ToUpperInvariant()) {
				'KB' { $sizeMB = $value / 1024 }
				'MB' { $sizeMB = $value }
				'GB' { $sizeMB = $value * 1024 }
			}
		}
		if ($sizeMB -gt $MaxSizeMB) {
			$skippedBySize += [pscustomobject]@{ Title = $title; Size = [string]$file.FileSize; Url = $link }
			continue
		}

		$candidates += [pscustomobject]@{
			Group  = $groupName
			Title  = $title
			Size   = [string]$file.FileSize
			Url    = $link
			Sha256 = ([string]$file.sha256).Trim().ToUpperInvariant()
			Name   = [IO.Path]::GetFileName(($link -split '\?')[0])
		}
	}
}

if ($skippedGroups -gt 0) { Write-Recipe "$skippedGroups catalogue group(s) left out as not relevant here" }

if ($skippedBySize.Count -gt 0) {
	Write-Warn "$($skippedBySize.Count) package(s) are larger than $MaxSizeMB MB and were left out; raise the ceiling, or fetch them by hand:"
	foreach ($item in $skippedBySize) { Write-Plain "$($item.Title) ($($item.Size))"; Write-Plain "    $($item.Url)" }
}

if ($candidates.Count -eq 0) {
	Write-Warn "the catalogue for $Model has nothing for what this machine is missing"
	exit 3
}

# ---- 4. What is not already here ----

$root = Join-Path $Path 'ASUS'
$toFetch = @()
foreach ($item in $candidates) {
	$folder = Join-Path $root ([IO.Path]::GetFileNameWithoutExtension($item.Name))
	$marker = Join-Path $folder '.asus-source.txt'
	if (-not $Force -and (Test-Path -LiteralPath $marker)) {
		$previous = ''
		try { $previous = (Get-Content -LiteralPath $marker -Raw -ErrorAction Stop) } catch { }
		# No sha256 published means the marker can only say "the same file name was unpacked
		# here", which is still enough not to pull 900 MB down a second time
		if ([string]::IsNullOrWhiteSpace($item.Sha256) -or $previous -match [regex]::Escape($item.Sha256)) {
			Write-Recipe "Already in the library: $($item.Title)"
			continue
		}
	}
	$toFetch += [pscustomobject]@{ Item = $item; Folder = $folder; Marker = $marker }
}

if ($toFetch.Count -eq 0) {
	Write-Recipe "Everything the catalogue offers for this machine is already under $root"
	exit 1
}

Write-Recipe "$($toFetch.Count) package(s) to fetch:"
foreach ($entry in $toFetch) { Write-Plain "$($entry.Item.Group) - $($entry.Item.Title) ($($entry.Item.Size))" }

if ($Check) {
	Write-Recipe "Check only, nothing was downloaded"
	exit 0
}

try {
	if (-not (Test-Path -LiteralPath $root)) { New-Item -ItemType Directory -Path $root -Force | Out-Null }
} catch {
	Write-Fail "$root could not be created: $($_.Exception.Message)"
	exit 2
}

$fetched = 0
$failed = 0

foreach ($entry in $toFetch) {
	$item = $entry.Item
	# GetTempPath, not $env:TEMP: the variable is not set in every context a scheduled
	# task runs a recipe from, and a null there stops the run with a binding error
	$tempRoot = [IO.Path]::GetTempPath()
	if ([string]::IsNullOrWhiteSpace($tempRoot)) { $tempRoot = $root }
	$temp = Join-Path $tempRoot $item.Name

	# Some of these URLs carry spaces in the path - the NUC14RV pack has three - and a raw
	# space is not something a request survives. The ?model= tail is ornamental and kept
	# only so that a URL printed on the console is the one the site itself serves.
	$link = $item.Url -replace ' ', '%20'

	Write-Recipe "Downloading $($item.Title) ($($item.Size))"
	try {
		if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
		# WebClient, not Invoke-WebRequest: on Windows PowerShell 5.1 the latter builds the
		# whole response in memory, and these are packages of several hundred megabytes
		$client = New-Object System.Net.WebClient
		$client.DownloadFile($link, $temp)
		$client.Dispose()
	} catch {
		Write-Fail "$($item.Title) could not be downloaded: $($_.Exception.Message)"
		Write-Plain $link
		$failed++
		continue
	}

	if (-not [string]::IsNullOrWhiteSpace($item.Sha256)) {
		$actual = ''
		try { $actual = (Get-FileHash -LiteralPath $temp -Algorithm SHA256 -ErrorAction Stop).Hash.ToUpperInvariant() } catch { }
		if ($actual -and $actual -ne $item.Sha256) {
			Write-Fail "$($item.Name) does not match the sha256 the catalogue publishes, so it is not unpacked"
			Write-Plain "expected $($item.Sha256)"
			Write-Plain "got      $actual"
			Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
			$failed++
			continue
		}
	}

	# Unpacked, not left as a .zip: cats install Drivers installs .inf packages and can only
	# name an archive to the operator
	try {
		if (Test-Path -LiteralPath $entry.Folder) { Remove-Item -LiteralPath $entry.Folder -Recurse -Force -ErrorAction SilentlyContinue }
		New-Item -ItemType Directory -Path $entry.Folder -Force | Out-Null
		Expand-Zip $temp $entry.Folder
	} catch {
		Write-Fail "$($item.Name) could not be unpacked: $($_.Exception.Message)"
		Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
		$failed++
		continue
	}

	# Some of these packages hold another archive rather than the driver itself - the GNA
	# one is a folder with a .zip in it - and an .inf that stays zipped is an .inf
	# cats install Drivers cannot see. Unpacked in place until no archive is left, with a
	# ceiling on the rounds so that a zip that somehow contains itself does not spin here.
	for ($round = 1; $round -le 3; $round++) {
		$inner = @(Get-ChildItem -LiteralPath $entry.Folder -Filter '*.zip' -Recurse -File -ErrorAction SilentlyContinue)
		if ($inner.Count -eq 0) { break }
		foreach ($archive in $inner) {
			$target = Join-Path $archive.DirectoryName ([IO.Path]::GetFileNameWithoutExtension($archive.Name))
			try {
				Expand-Zip $archive.FullName $target
				Remove-Item -LiteralPath $archive.FullName -Force -ErrorAction SilentlyContinue
			} catch {
				Write-Warn "$($archive.Name) is inside $($item.Name) and could not be unpacked: $($_.Exception.Message)"
				# Left where it is: an operator can still open it by hand
			}
		}
	}

	$lines = @(
		"title  : $($item.Title)",
		"group  : $($item.Group)",
		"model  : $Model",
		"size   : $($item.Size)",
		"url    : $($item.Url)",
		"sha256 : $($item.Sha256)",
		"fetched: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
	)
	try { Set-Content -LiteralPath $entry.Marker -Value $lines -Encoding ASCII -ErrorAction Stop } catch {
		Write-Warn "the marker file could not be written, so this package will be fetched again next time"
	}
	Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue

	$infCount = @(Get-ChildItem -LiteralPath $entry.Folder -Filter '*.inf' -Recurse -File -ErrorAction SilentlyContinue).Count
	if ($infCount -gt 0) {
		Write-Recipe "$($item.Title): $infCount .inf file(s) under $($entry.Folder)"
	} else {
		Write-Warn "$($item.Title) holds no .inf file: cats install Drivers will name it, an operator runs it"
	}
	$fetched++
}

if ($fetched -eq 0) {
	Write-Fail "no package could be added to the library"
	exit 2
}
if ($failed -gt 0) {
	Write-Warn "$failed package(s) failed; $fetched were added to $root"
} else {
	Write-Recipe "$fetched package(s) added to $root"
}

exit 0
