# Find the current ONLYOFFICE Desktop Editors, decide whether this machine needs it, and download it.
#
# Prints KEY=VALUE lines on standard output and nothing else, like the other helpers: the caller is
# a batch recipe that parses them with for /f - see cats-recipes\OnlyOffice.bat.
#
# Where the version comes from. ONLYOFFICE publishes the feed its own updater reads, appcast.json,
# with the current version and, per architecture, the MSI on GitHub and on download.onlyoffice.com
# together with its MD5. That feed is the single source here: version, URLs and checksum come from
# the same document, so they cannot disagree with each other. The fixed «latest» URLs alone would
# give the bytes but no version to compare against what is installed.
#
# What is checked. The MD5 from the feed, which catches a truncated or corrupt download, and the
# Authenticode signature, which must be by «Ascensio System SIA», the company behind ONLYOFFICE.
# The MD5 alone is not a check against substitution - it comes over the same kind of connection as
# the file - the signature is.
#
#   ps\onlyoffice-fetch.ps1 -Out C:\Admin\Installers\OnlyOffice
#   ps\onlyoffice-fetch.ps1 -Out ... -Lang de-DE         force the UI language

[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)] [string] $Out,
	[string] $Lang = ''
)

$ErrorActionPreference = 'Stop'

$Feed = 'https://download.onlyoffice.com/install/desktop/editors/windows/onlyoffice/appcast.json'

# The UI languages the installer knows, in the form its LOCALE property takes: the AppLocale list
# of the ONLYOFFICE Inno Setup sources (desktop-apps, package/inno/_messages.iss), which is also
# what the MSI writes to the registry value «locale». A culture that is not in the list falls back
# to the entry of the same language - it-CH to it-IT, de-AT to de-DE - and then to en-US.
$Locales = @(
	'en-US', 'en-GB', 'ru-RU', 'de-DE', 'fr-FR', 'es-ES', 'sk-SK', 'cs-CZ', 'it-IT', 'pt-PT',
	'pt-BR', 'pl-PL', 'zh-CN', 'zh-TW', 'ca-ES', 'da-DK', 'el-GR', 'fi-FI', 'he-IL', 'hr-HR',
	'hu-HU', 'hy-AM', 'id-ID', 'no-NO', 'ro-RO', 'sl-SI', 'sv-SE', 'tr-TR', 'ja-JP', 'ko-KR',
	'bg-BG', 'nl-NL', 'vi-VN', 'lv-LV', 'be-BY', 'uk-UA'
)

# Written straight to the console stream and not with Write-Output, for the reason given in
# ps\tdf-fetch.ps1: a Write-Output inside a function that also returns a value joins the return.
function Emit([string] $key, [string] $value) {
	$flat = ($value -replace '\s*[\r\n]+\s*', ' ').Trim()
	$line = '{0}={1}' -f $key, $flat
	[Console]::Out.WriteLine($line)
}

function Get-Locale([string] $culture) {
	if (-not $culture) { return 'en-US' }
	foreach ($l in $Locales) { if ($l -ieq $culture) { return $l } }
	# Chinese is the one language where the script, not the country, decides: zh-Hans-CN and zh-SG
	# read simplified characters, zh-Hant-TW and zh-HK traditional ones.
	if ($culture -match '^zh-(Hant|TW|HK|MO)') { return 'zh-TW' }
	if ($culture -match '^zh') { return 'zh-CN' }
	if ($culture -match '^(nb|nn)') { return 'no-NO' }
	$two = $culture.Split('-')[0]
	foreach ($l in $Locales) { if ($l.Split('-')[0] -ieq $two) { return $l } }
	return 'en-US'
}

function Get-Md5([string] $file) {
	$md5 = [System.Security.Cryptography.MD5]::Create()
	$s = [System.IO.File]::OpenRead($file)
	try { return ([BitConverter]::ToString($md5.ComputeHash($s)) -replace '-', '').ToLower() }
	finally { $s.Dispose() }
}

# Same policy as ps\tdf-fetch.ps1: a wrong hash or a missing or foreign signature is fatal, a chain
# this machine cannot complete is reported and accepted.
function Test-Package([string] $file, [string] $expected) {
	$have = Get-Md5 $file
	if ($expected -and $have -ne $expected.ToLower()) {
		Emit 'NOTE' ('MD5 {0}, the feed says {1}' -f $have, $expected)
		return $false
	}
	$sig = Get-AuthenticodeSignature -LiteralPath $file
	$subject = ''
	if ($sig.SignerCertificate) { $subject = $sig.SignerCertificate.Subject }
	if ($sig.Status -eq 'HashMismatch' -or $sig.Status -eq 'NotSigned') {
		Emit 'NOTE' ('the package is {0}' -f $sig.Status)
		return $false
	}
	if ($subject -notmatch 'Ascensio System') {
		Emit 'NOTE' ('the package is signed by {0}, not by Ascensio System SIA' -f $subject)
		return $false
	}
	if ($sig.Status -ne 'Valid') {
		Emit 'SIGNOTE' ('signature status {0}, accepted: signed by Ascensio but this machine cannot complete the chain' -f $sig.Status)
	}
	return $true
}

try {
	[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072

	# The architecture of the operating system, not of this PowerShell: a 32 bit host on a 64 bit
	# Windows must still install the x64 package.
	$arch = $env:PROCESSOR_ARCHITEW6432
	if (-not $arch) { $arch = $env:PROCESSOR_ARCHITECTURE }
	switch ($arch) {
		'AMD64' { $key = 'win_64' }
		'ARM64' { $key = 'win_arm64' }
		'x86'   { $key = 'win_32' }
		default { Emit 'ERROR' ('no ONLYOFFICE package for the architecture {0}' -f $arch); exit 2 }
	}

	$json = (New-Object System.Net.WebClient).DownloadString($Feed) | ConvertFrom-Json
	$version = [string] $json.package.version
	$msi = $json.package.$key.msi
	if (-not $version -or -not $msi -or -not $msi.url2) {
		Emit 'ERROR' ('the ONLYOFFICE feed has no MSI for {0}: {1} changed its layout' -f $key, $Feed)
		exit 2
	}

	$culture = (Get-Culture).Name
	try { $culture = [System.Globalization.CultureInfo]::CurrentUICulture.Name } catch { }
	if ($Lang) { $locale = Get-Locale $Lang } else { $locale = Get-Locale $culture }

	Emit 'VERSION' $version
	Emit 'OSUICULTURE' $culture
	Emit 'LOCALE' $locale

	# Registered as «ONLYOFFICE <version> (<arch>)» under its own uninstall key; the MSI's entry is
	# hidden (ARPSYSTEMCOMPONENT). DisplayVersion carries the four components the feed also gives.
	$k = @(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
		'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue)
	$k = @($k.Where({ $_.DisplayName -like 'ONLYOFFICE*' }))
	if ($k.Count -gt 0) {
		Emit 'INSTALLED' $k[0].DisplayVersion
		if (([string] $k[0].DisplayVersion).StartsWith($version)) {
			Emit 'CURRENT' '1'
			exit 0
		}
	}

	if (-not (Test-Path -LiteralPath $Out)) { New-Item -ItemType Directory -Path $Out -Force | Out-Null }
	$file = Split-Path -Leaf ([string] $msi.url2)
	$dest = Join-Path $Out $file
	Emit 'FILE' $dest

	# The URL is the same for every version, so a file already on disk is only reused if it is the
	# one the feed describes now.
	if (Test-Path -LiteralPath $dest) {
		if (Test-Package $dest $msi.md5) { Emit 'FETCHED' 'already on disk'; exit 0 }
		Remove-Item -LiteralPath $dest -Force
	}

	$curl = ''
	if ($env:SystemRoot) { $curl = Join-Path $env:SystemRoot 'System32\curl.exe' }
	if (-not $curl -or -not (Test-Path -LiteralPath $curl)) { $curl = '' }

	# The vendor host first, GitHub second, both as the feed names them. GitHub is the fallback and
	# not the rule: its releases do not always carry the MSI - the 10.0.0 release has only the .exe
	# installers, and the feed's GitHub URL answers 404 - while download.onlyoffice.com does.
	$sources = @(@{ Name = 'download.onlyoffice.com'; Url = [string] $msi.url2 },
		@{ Name = 'github.com'; Url = [string] $msi.url })
	$part = $dest + '.part'
	foreach ($s in $sources) {
		if (-not $s.Url) { continue }
		Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue
		try {
			if ($curl) {
				$prev = $ErrorActionPreference
				$ErrorActionPreference = 'Continue'
				$text = (& $curl --location --fail --no-progress-meter --show-error --connect-timeout 20 `
					--speed-limit 10240 --speed-time 30 -o $part $s.Url 2>&1 | Out-String)
				$code = $LASTEXITCODE
				$ErrorActionPreference = $prev
				if ($code -ne 0) { Emit 'NOTE' ('{0}: curl exit {1} {2}' -f $s.Name, $code, $text); continue }
			} else {
				(New-Object System.Net.WebClient).DownloadFile($s.Url, $part)
			}
		} catch {
			Emit 'NOTE' ('{0}: {1}' -f $s.Name, $_.Exception.Message)
			continue
		}
		if (-not (Test-Package $part $msi.md5)) {
			Emit 'NOTE' ('what {0} served was discarded' -f $s.Name)
			Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue
			continue
		}
		Move-Item -LiteralPath $part -Destination $dest -Force
		Emit 'SOURCE' $s.Name
		Emit 'FETCHED' $dest
		exit 0
	}

	Emit 'ERROR' 'no source served a package that verifies: see the NOTE lines above'
	exit 2
} catch {
	Emit 'ERROR' $_.Exception.Message
	exit 2
}
