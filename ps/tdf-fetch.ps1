# Download a file published by The Document Foundation, from whichever mirror answers.
#
# Prints KEY=VALUE lines on standard output and nothing else, like the lookup scripts: the caller
# is a batch recipe that parses them with for /f - see cats-recipes\LibreOffice.bat.
#
# Why this exists rather than a plain WebClient call, which is what every other recipe in this
# repository uses. On 2026-08-27 the first field run of `cats install LibreOffice` failed at the
# download with «The underlying connection was closed: An unexpected error occurred on a send»:
# download.documentfoundation.org, the official mirror redirector, killed the connection. The same
# host had already refused the agent's own machine the same day - connection reset, on curl and on
# .NET alike, while www.libreoffice.org, wiki.documentfoundation.org and four direct TDF mirrors
# answered normally in the same minute. Two machines, two operating systems, two TLS stacks, one
# host: the redirector is the part that fails, not the download and not the network. Every other
# recipe here downloads from a vendor host that has never done this, so the fix belongs to the TDF
# packages and not to the other recipes.
#
# What that buys, and what it costs. The redirector is still tried first - it is the official path
# and it picks a mirror near the machine, which on a client network is the right thing - but its
# failure is no longer the end of the recipe: the sources below are tried in turn until one serves
# the file. The cost is that the bytes may come from a third party instead of from TDF's own
# redirect, which is why this script verifies the Authenticode signature of what it downloaded
# before letting the caller install it. Verified on the 26.8.0 x86-64 MSI, 2026-08-27: signed by
# «The Document Foundation», issued by Certum Code Signing 2021 CA, countersigned for time. TDF
# publishes no .sha256 next to the packages - only a .asc, which needs a GnuPG that a Wild Cat
# does not have - so the signature already in the file is the check that costs nothing.
#
#   ps\tdf-fetch.ps1 -Path stable/26.8.0/win/x86_64 -File LibreOffice_26.8.0_Win_x86-64.msi -Out ...
#   ps\tdf-fetch.ps1 ... -Optional        a 404 on every source is MISSING=1, not an error

[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)] [string] $Path,
	[Parameter(Mandatory = $true)] [string] $File,
	[Parameter(Mandatory = $true)] [string] $Out,
	[switch] $Optional
)

$ErrorActionPreference = 'Stop'

# In order of preference. The redirector first: official, and it resolves to a mirror close to the
# machine, which matters on a client line and cannot be reproduced by a fixed list. Then four
# direct mirrors, all verified to carry the full Windows tree - x86_64, aarch64 and the helppacks -
# at the path below on 2026-08-27. init7 is second because the fleet is in Switzerland and so is
# init7; the others are there so that one mirror's maintenance is not an outage.
$Sources = @(
	@{ Name = 'documentfoundation.org'; Base = 'https://download.documentfoundation.org/libreoffice' },
	@{ Name = 'init7 (CH)';             Base = 'https://mirror.init7.net/tdf/libreoffice' },
	@{ Name = 'kumi.systems (AT)';      Base = 'https://mirror.kumi.systems/tdf/libreoffice' },
	@{ Name = 'RWTH Aachen (DE)';       Base = 'https://ftp.halifax.rwth-aachen.de/tdf/libreoffice' },
	@{ Name = 'dotsrc.org (DK)';        Base = 'https://mirrors.dotsrc.org/tdf/libreoffice' }
)

# Written straight to the console stream and not with Write-Output, because the functions below
# emit *and* return a value: a Write-Output inside one of them joins its return value, so
# `return $false` after an Emit comes back as a two-element array - which is truthy, and would have
# made a hash mismatch pass the check. Found by running the error paths, 2026-08-27.
function Emit([string] $key, [string] $value) {
	# Formatted on its own line: inside a .NET method call the comma separates arguments, so
	# WriteLine('{0}={1}' -f $key, $value) is parsed as two arguments and the format runs out of
	# operands. Cmdlets do not have that ambiguity, methods do.
	# Newlines are squeezed out of the value: an exception message can span lines, and a KEY=VALUE
	# contract that the caller reads with for /f cannot afford a value that becomes a second line.
	$flat = ($value -replace '\s*[\r\n]+\s*', ' ').Trim()
	$line = '{0}={1}' -f $key, $flat
	[Console]::Out.WriteLine($line)
}

# Valid, and signed by TDF. Anything else is described rather than judged, because the reason to
# check is a corrupt or substituted download and not the state of this machine's root store: a
# hash mismatch or an unsigned file is fatal, while a chain that will not build - a stale root
# store, no way out to the CRL - is reported and accepted. Turning the verification into a new
# way for the recipe to fail on a machine that is merely behind on updates would trade a real
# problem for an invented one.
function Test-TdfSignature([string] $file) {
	$sig = $null
	try {
		$sig = Get-AuthenticodeSignature -LiteralPath $file
	} catch {
		Emit 'SIGNOTE' ('the signature of {0} could not be read: {1}' -f $File, $_.Exception.Message)
		return $true
	}

	$subject = ''
	if ($sig.SignerCertificate) { $subject = $sig.SignerCertificate.Subject }

	if ($sig.Status -eq 'HashMismatch' -or $sig.Status -eq 'NotSigned') {
		Emit 'SIGERROR' ('{0} is {1}: the file is not the package TDF published' -f $File, $sig.Status)
		return $false
	}
	if ($subject -and $subject -notmatch 'The Document Foundation') {
		Emit 'SIGERROR' ('{0} is signed by {1}, not by The Document Foundation' -f $File, $subject)
		return $false
	}
	if ($sig.Status -ne 'Valid') {
		Emit 'SIGNOTE' (('signature status {0}, accepted: the file is TDF-signed but this ' +
			'machine cannot complete the chain') -f $sig.Status)
		return $true
	}

	Emit 'SIGNER' 'The Document Foundation'
	return $true
}

# The HTTP status out of curl's own --write-out, and not curl's exit code. Measured on 2026-08-27:
# curl 8.7 with --fail over HTTP/2 - which every one of these mirrors speaks - reports a 404 as
# exit 56, «failure receiving network data», not as the 22 that --fail documents. Exit 56 is also
# what a genuinely broken connection gives, so reading the exit code alone would file «this mirror
# does not carry the helppack» under «the network is down», and a missing help pack would abort the
# recipe. --write-out prints the status even when the transfer failed.
function Get-CurlStatus($output) {
	$m = [regex]::Match(($output | Out-String), 'STATUS=(\d+)')
	if ($m.Success) { return [int] $m.Groups[1].Value }
	return 0
}

# ErrorActionPreference goes back to Continue around every native call: with it on Stop, a command
# that writes to stderr under 2>&1 raises NativeCommandError and the script dies on the first
# mirror that prints a diagnostic. Keeping stderr is worth the two lines - it is what tells the
# operator why a mirror refused.
function Invoke-Curl([string] $curl, [string[]] $curlArgs) {
	$prev = $ErrorActionPreference
	$ErrorActionPreference = 'Continue'
	$text = (& $curl @curlArgs 2>&1 | Out-String)
	$code = $LASTEXITCODE
	$ErrorActionPreference = $prev
	return @{ Code = $code; Text = $text; Status = (Get-CurlStatus $text) }
}

# One byte, twenty seconds, before committing to 375 MB. Not caution for its own sake: the
# redirector does not only reset, it can also accept the connection and then never answer, and
# measured on 2026-08-27 that cost 123 s on the first source alone - --connect-timeout does not
# cover a stall after the connection is up, and --max-time cannot be used on the real transfer
# without capping a legitimate slow download of a 375 MB package. A ranged GET bounds the wait for
# the first byte, which is the only thing that needs bounding, and it settles 404 cheaply as well:
# a mirror that does not carry the file says so without anyone downloading anything.
# Returns 0 answers, 404 not published here, 1 anything else.
function Test-Source([string] $url, [string] $curl, [string] $scratch) {
	$r = Invoke-Curl $curl @(
		'--location', '--silent', '--show-error', '--max-time', '20',
		'--range', '0-0', '--write-out', "`nSTATUS=%{http_code}`n", '-o', $scratch, $url)

	if ($r.Status -eq 200 -or $r.Status -eq 206) { return 0 }
	if ($r.Status -ge 400 -and $r.Status -lt 500) { return 404 }
	Emit 'NOTE' ('curl exit {0}, HTTP {1}' -f $r.Code, $r.Status)
	foreach ($line in ($r.Text -split "`r?`n")) {
		if ($line -match '^curl:') { Emit 'NOTE' $line.Trim() }
	}
	return 1
}

# curl.exe if Windows has it - it is in System32 from Windows 10 1803 - because it resumes a part
# file, gives up on a stalled line instead of hanging, and brings its own TLS. WebClient is the
# fallback for anything older, with TLS 1.2 forced on: Windows PowerShell 5.1 still negotiates
# TLS 1.0 first on some builds, and no TDF mirror accepts it. Returns 0 served, 404 not published
# here, 1 anything else.
function Invoke-Fetch([string] $url, [string] $part, [string] $curl) {
	if ($curl) {
		# --fail so an HTML error page is not written to disk as if it were a package, -C - to
		# pick up a part file left by an earlier attempt, and the speed guard so a mirror that
		# goes quiet halfway through costs half a minute rather than the session.
		$curlArgs = @(
			'--location', '--fail', '--no-progress-meter', '--show-error',
			'--connect-timeout', '20', '--speed-limit', '10240', '--speed-time', '30',
			'--retry', '1', '--retry-delay', '3',
			'--write-out', "`nSTATUS=%{http_code}`n", '-o', $part)

		$r = Invoke-Curl $curl ($curlArgs + @('-C', '-', $url))
		if ($r.Code -eq 0 -and ($r.Status -eq 200 -or $r.Status -eq 206)) { return 0 }
		if ($r.Status -ge 400 -and $r.Status -lt 500) { return 404 }

		# 33 and 36: the server will not resume, or the part file is already longer than the file
		# on the server. Start it over once rather than reporting a failure that a delete fixes.
		if (($r.Code -eq 33 -or $r.Code -eq 36) -and (Test-Path -LiteralPath $part)) {
			Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue
			$r = Invoke-Curl $curl ($curlArgs + @($url))
			if ($r.Code -eq 0 -and $r.Status -eq 200) { return 0 }
		}

		Emit 'NOTE' ('curl exit {0}, HTTP {1}' -f $r.Code, $r.Status)
		foreach ($line in ($r.Text -split "`r?`n")) {
			if ($line -match '^curl:') { Emit 'NOTE' $line.Trim() }
		}
		return 1
	}

	try {
		[Net.ServicePointManager]::SecurityProtocol =
			[Net.ServicePointManager]::SecurityProtocol -bor 3072
	} catch { }
	try {
		(New-Object System.Net.WebClient).DownloadFile($url, $part)
		return 0
	} catch [System.Net.WebException] {
		$r = $_.Exception.Response
		if ($r -and [int] $r.StatusCode -ge 400 -and [int] $r.StatusCode -lt 500) { return 404 }
		Emit 'NOTE' $_.Exception.Message
		return 1
	} catch {
		Emit 'NOTE' $_.Exception.Message
		return 1
	}
}

try {
	$dir = Split-Path -Parent $Out
	if ($dir -and -not (Test-Path -LiteralPath $dir)) {
		New-Item -ItemType Directory -Path $dir -Force | Out-Null
	}

	# A file already at the destination is only trusted if it verifies. A truncated or half
	# written package left by an earlier run would otherwise be handed to msiexec, which is a
	# worse failure than downloading 375 MB again: the error would name the installer instead of
	# the download.
	if (Test-Path -LiteralPath $Out) {
		if (Test-TdfSignature $Out) {
			Emit 'FETCHED' 'already on disk'
			exit 0
		}
		Emit 'NOTE' ('the copy already in {0} does not verify, downloading it again' -f $dir)
		Remove-Item -LiteralPath $Out -Force
	}

	$curl = ''
	if ($env:SystemRoot) { $curl = Join-Path $env:SystemRoot 'System32\curl.exe' }
	if (-not $curl -or -not (Test-Path -LiteralPath $curl)) {
		$curl = ''
		Emit 'NOTE' 'no curl.exe on this Windows, falling back to WebClient without resume'
	}

	# Downloaded beside the destination and moved into place only once it verifies, so that the
	# file the recipe tests for with `if not exist` is never a partial one. The part file is left
	# behind on failure on purpose: it is what the next run resumes, and what whoever looks at a
	# failure can measure.
	$part = $Out + '.part'
	$scratch = $Out + '.probe'
	$missing = 0
	$failed = 0

	foreach ($s in $Sources) {
		$url = '{0}/{1}/{2}' -f $s.Base, $Path.Trim('/'), $File

		if ($curl) {
			$rc = Test-Source $url $curl $scratch
			if ($rc -eq 404) {
				$missing++
				Emit 'NOTE' ('{0} does not publish {1}' -f $s.Name, $File)
				continue
			}
			if ($rc -ne 0) {
				$failed++
				Emit 'NOTE' ('{0} did not answer' -f $s.Name)
				continue
			}
		}

		$rc = Invoke-Fetch $url $part $curl
		if ($rc -eq 404) {
			$missing++
			Emit 'NOTE' ('{0} does not publish {1}' -f $s.Name, $File)
			continue
		}
		if ($rc -ne 0) {
			$failed++
			Emit 'NOTE' ('{0} did not serve the file' -f $s.Name)
			continue
		}

		if (-not (Test-TdfSignature $part)) {
			Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue
			$failed++
			Emit 'NOTE' ('what {0} served was discarded' -f $s.Name)
			continue
		}

		Move-Item -LiteralPath $part -Destination $Out -Force
		Remove-Item -LiteralPath $scratch -Force -ErrorAction SilentlyContinue
		Emit 'SOURCE' $s.Name
		Emit 'FETCHED' $Out
		exit 0
	}

	Remove-Item -LiteralPath $scratch -Force -ErrorAction SilentlyContinue

	# «Every source that answered said 404» rather than «every source said 404», because the
	# redirector fails intermittently on this fleet and one unreachable source should not turn a
	# help pack that genuinely does not exist into a warning. Two independent 404s are required
	# all the same: one mirror's answer is not a fact about what TDF publishes.
	if ($missing -ge 2 -and ($missing + $failed) -eq $Sources.Count) {
		if ($Optional) {
			Emit 'MISSING' '1'
			exit 0
		}
		Emit 'ERROR' (('no TDF mirror publishes {0}: the lookup named a package that is not ' +
			'there') -f $File)
		exit 2
	}
	Emit 'ERROR' (('none of the {0} TDF sources served {1}: see the NOTE lines above for what ' +
		'each one answered') -f $Sources.Count, $File)
	exit 2
} catch {
	Emit 'ERROR' $_.Exception.Message
	exit 2
}
