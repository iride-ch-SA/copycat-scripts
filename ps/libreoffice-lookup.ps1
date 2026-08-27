# LibreOffice lookup: current release, Windows package, UI language of this machine.
#
# Prints KEY=VALUE lines on standard output and nothing else. The caller is a batch recipe that
# parses them with for /f - see cats-recipes\LibreOffice.bat. Errors are printed the same way,
# as ERROR=..., so the recipe can name the cause instead of only reporting that nothing came back.
#
# Why a lookup at all. The Document Foundation publishes no evergreen URL: every release lives
# under its own version-numbered path, so a hardcoded URL goes stale the way the HPSA9 SoftPaq
# number does. The download page carries the current version in a <select>, and the Windows MSI
# URL itself in the page body. Both are read here. The URL is composed and then *required to
# appear in the page*: if TDF changes the layout this script fails loudly instead of downloading
# from a path nobody published.
#
# Why the language is computed here. On Windows the LibreOffice MSI is multilingual - the mirror
# carries helppack MSIs but no langpack MSIs, because every UI language is inside the one
# installer and is chosen at install time through the UI_LANGS property, documented by TDF since
# 3.5.5. Windows is therefore the platform where the language is an install parameter, not a
# second download, and that is what this script produces.
#
#   ps\libreoffice-lookup.ps1
#   ps\libreoffice-lookup.ps1 -Branch previous          the still branch instead of the newest
#   ps\libreoffice-lookup.ps1 -Lang de                  force the UI language

[CmdletBinding()]
param(
	[ValidateSet('latest', 'previous')] [string] $Branch = 'latest',
	[ValidateSet('', 'x86_64', 'aarch64')] [string] $Arch = '',
	[string] $Lang = ''
)

$ErrorActionPreference = 'Stop'

$DownloadPage = 'https://www.libreoffice.org/download/download-libreoffice/'

# The LibreOffice language codes that are not a bare ISO 639 code. Read off the download page,
# 2026-08-27: every other one of the 126 published languages is the two or three letter code.
$Variants = @(
	'bn-IN', 'ca-valencia', 'en-GB', 'en-US', 'en-ZA', 'kmr-Latn',
	'pa-IN', 'pt-BR', 'sa-IN', 'sat-Olck', 'sr-Latn', 'sw-TZ', 'zh-CN', 'zh-TW'
)

function Emit([string] $key, [string] $value) {
	Write-Output ('{0}={1}' -f $key, $value)
}

# A Windows culture name - it-CH, de-CH, pt-BR, zh-Hans-CN - mapped to the LibreOffice code.
# There is no bare 'en' and no bare 'zh' in LibreOffice, hence the two explicit branches: a
# culture that falls through to its base code there would be an invalid code, and an invalid
# code makes the installer fall back to en_US silently, which is the failure we are avoiding.
function ConvertTo-LibreOfficeLang([string] $tag) {
	if (-not $tag) { return 'en-US' }
	foreach ($v in $Variants) { if ($v -ieq $tag) { return $v } }

	$parts = $tag -split '-'
	$base = $parts[0].ToLowerInvariant()
	$region = ''
	if ($parts.Count -gt 1) { $region = $parts[$parts.Count - 1].ToUpperInvariant() }

	switch ($base) {
		'en' { return 'en-GB' }
		'zh' { if ($tag -match 'Hant|TW|HK|MO') { return 'zh-TW' } else { return 'zh-CN' } }
		'pt' { if ($region -eq 'BR') { return 'pt-BR' } else { return 'pt' } }
		'sr' { if ($tag -match 'Latn') { return 'sr-Latn' } else { return 'sr' } }
		'bn' { if ($region -eq 'IN') { return 'bn-IN' } else { return 'bn' } }
		'pa' { return 'pa-IN' }
		default { return $base }
	}
}

try {
	# Windows PowerShell 5.1 negotiates TLS 1.0 by default on older builds, and neither
	# libreoffice.org nor the mirror redirector accepts it any more.
	try {
		[Net.ServicePointManager]::SecurityProtocol =
			[Net.ServicePointManager]::SecurityProtocol -bor 3072
	} catch { }

	if (-not $Arch) {
		switch ($env:PROCESSOR_ARCHITECTURE) {
			'AMD64' { $Arch = 'x86_64' }
			'ARM64' { $Arch = 'aarch64' }
		}
	}
	if (-not $Arch) {
		# The concatenation is parenthesised on purpose: -f binds tighter than +, so without it
		# the format is applied to the second fragment alone and the message reaches the operator
		# with a literal {0} in it. Three messages in this script shipped that way on 2026-08-27.
		throw (('this Windows reports PROCESSOR_ARCHITECTURE={0}, and The Document Foundation ' +
			'publishes no Windows build for it: install by hand') -f $env:PROCESSOR_ARCHITECTURE)
	}
	# The file name says x86-64 where the path says x86_64. Not a typo, TDF's own naming.
	$token = if ($Arch -eq 'x86_64') { 'x86-64' } else { 'aarch64' }

	# ---- language ---------------------------------------------------------------------------
	#
	# Two cultures, and they can differ: CurrentUICulture is the display language in force for
	# the account running this - the operator's elevated prompt - while InstalledUICulture is the
	# language Windows itself was installed in. A machine imaged in English and then switched to
	# Italian by the user answers en-US to the second and it-IT to the first. The display
	# language is the one the user reads, so it wins; both are printed so that whoever looks at
	# the log can see which one was taken.
	$current = [System.Globalization.CultureInfo]::CurrentUICulture.Name
	$installed = [System.Globalization.CultureInfo]::InstalledUICulture.Name
	Emit 'OSUICULTURE' $current
	Emit 'OSINSTALLED' $installed

	if ($Lang) {
		$lo = $Lang
		Emit 'LANGSOURCE' 'forced on the command line'
	} else {
		$tag = $current
		if (-not $tag) { $tag = $installed }
		$lo = ConvertTo-LibreOfficeLang $tag
		Emit 'LANGSOURCE' $tag
	}
	Emit 'LANG' $lo

	# UI_LANGS wants the underscore form - the TDF examples are en_US, pt_BR, de, fr - and a
	# comma-separated list. en_US is appended because, unlike the automatic selection, an
	# explicit UI_LANGS does *not* install it, and it is the language the installer falls back
	# to if anything about the primary one is wrong.
	$ui = $lo -replace '-', '_'
	if ($ui -eq 'en_US') { Emit 'UILANGS' 'en_US' } else { Emit 'UILANGS' ('{0},en_US' -f $ui) }

	# ---- version and package ----------------------------------------------------------------
	$page = Invoke-WebRequest -Uri $DownloadPage -UseBasicParsing -TimeoutSec 60
	$html = $page.Content

	# value="latest" is the newest release, value="previous" the still branch. The other two
	# options, upper_pre and middle_pre, are release candidates and live under /testing/ - they
	# are excluded by asking for these two values and by requiring /stable/ in the URL below.
	$pattern = '<option value="{0}"[^>]*data-version-dir="([^"]+)"[^>]*data-version-file="([^"]+)"' -f $Branch
	$m = [regex]::Match($html, $pattern)
	if (-not $m.Success) {
		throw (("the download page no longer carries a '{0}' version option: TDF changed the " +
			'page and ps\libreoffice-lookup.ps1 has to be updated') -f $Branch)
	}
	$dir = $m.Groups[1].Value
	$file = $m.Groups[2].Value
	Emit 'VERSION' $file

	$msi = 'LibreOffice_{0}_Win_{1}.msi' -f $file, $token
	$rel = 'stable/{0}/win/{1}' -f $dir, $Arch
	$base = 'https://download.documentfoundation.org/libreoffice/{0}' -f $rel
	$url = '{0}/{1}' -f $base, $msi
	if ($html.IndexOf($url, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
		throw (('the download page does not publish {0}: it names a version this build of the ' +
			'page has no Windows package for') -f $url)
	}
	Emit 'FILE' $msi
	Emit 'URL' $url
	# The release path on its own, because the recipe no longer downloads from the URL above:
	# download.documentfoundation.org killed the connection on the first field run, 2026-08-27,
	# and ps\tdf-fetch.ps1 walks a list of mirrors of which the redirector is only the first.
	# The URL is still emitted, and still required to appear in the page, because that is what
	# proves the version and the architecture are published - and it is the address a human
	# should be given when the download fails.
	Emit 'RELPATH' $rel

	# ---- help pack --------------------------------------------------------------------------
	#
	# Optional, and deliberately not fatal. Local help in the machine's language is worth the few
	# megabytes, but LibreOffice falls back to the online help when it is absent, and not every
	# one of the 126 UI languages has one.
	#
	# Its name is emitted without being probed. Until 2026-08-27 a HEAD on the redirector decided
	# whether to emit it at all, which was wrong twice over: the redirector is the one TDF host
	# that will not answer this fleet, so the probe reported «no help pack» for every language
	# including the ones that have one - and the probe asked one host a question that the download
	# then asks five. ps\tdf-fetch.ps1 is called with -Optional instead, and a 404 from every
	# mirror is what now means the help pack does not exist. One mechanism, and the answer comes
	# from whoever is actually going to serve the file.
	$helpFile = 'LibreOffice_{0}_Win_{1}_helppack_{2}.msi' -f $file, $token, $lo
	Emit 'HELPFILE' $helpFile
	Emit 'HELPURL' ('{0}/{1}' -f $base, $helpFile)
} catch {
	Emit 'ERROR' $_.Exception.Message
}
