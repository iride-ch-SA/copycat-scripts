param(
	[string]$username,
	[ValidateSet("ask", "random")]
	[string]$mode = "random",
	[switch]$create,
	[switch]$force,
	[int]$length = 16
)

# ============================================================
#  set-user-password.ps1
#  Sets the password of a local user without ever putting it on
#  a command line, where any process listing would show it.
#    -mode random : a new password is generated and displayed
#    -mode ask    : the password is typed, never echoed
#    -create      : the account is created instead of updated
#  The account is always left enabled and with no expiration.
#  Nothing is written to disk: no log, no file, no clipboard.
#  With -mode random the script refuses to run when PowerShell
#  transcription is enabled by policy, because everything shown
#  on screen is written to the transcript file. Use -force to
#  run anyway. A transcript started by hand with Start-Transcript
#  cannot be detected and is not covered by this check.
# ============================================================

if (-not $username) {
	Write-Host "ERROR: Username expected as first parameter" -ForegroundColor Red
	exit 1
}

$lower = "abcdefghijkmnopqrstuvwxyz"
$upper = "ABCDEFGHJKLMNPQRSTUVWXYZ"
$digit = "23456789"
# Special characters kept to a set that no shell, script or CSV import mangles
$special = "#$*+-=?@_"

$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()

function Get-RandomChar {
	param([string]$set)

	$size = $set.Length
	# Rejection sampling: without it the modulo would favour the first chars
	$limit = 256 - (256 % $size)
	$byte = New-Object byte[] 1

	do {
		$rng.GetBytes($byte)
	} while ($byte[0] -ge $limit)

	return $set[$byte[0] % $size]
}

function New-Password {
	param([int]$size)

	$all = $lower + $upper + $digit + $special

	# One character per class first, so every class is guaranteed present
	$chars = New-Object System.Collections.ArrayList
	[void]$chars.Add((Get-RandomChar $lower))
	[void]$chars.Add((Get-RandomChar $upper))
	[void]$chars.Add((Get-RandomChar $digit))
	[void]$chars.Add((Get-RandomChar $special))

	for ($i = $chars.Count; $i -lt $size; $i++) {
		[void]$chars.Add((Get-RandomChar $all))
	}

	# Fisher-Yates, otherwise the first four positions would be predictable
	for ($i = $chars.Count - 1; $i -gt 0; $i--) {
		$limit = 256 - (256 % ($i + 1))
		$byte = New-Object byte[] 1
		do {
			$rng.GetBytes($byte)
		} while ($byte[0] -ge $limit)

		$j = $byte[0] % ($i + 1)
		$swap = $chars[$i]
		$chars[$i] = $chars[$j]
		$chars[$j] = $swap
	}

	return -join $chars
}

function Read-SecureText {
	param([System.Security.SecureString]$secure)

	$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
	Try {
		return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
	}
	Finally {
		[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
	}
}

function Get-TranscriptionPolicy {
	# The machine policy and the user policy are two distinct keys,
	# either one is enough to have every line of output written to disk
	$keys = @(
		"HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription",
		"HKCU:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription"
	)

	foreach ($key in $keys) {
		$policy = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
		if ($policy -and $policy.EnableTranscripting -eq 1) {
			return [PSCustomObject]@{
				Key       = $key
				Directory = $policy.OutputDirectory
			}
		}
	}

	return $null
}

$transcription = Get-TranscriptionPolicy

if ($mode -eq "random" -and $transcription -and -not $force) {
	Write-Host "ERROR: PowerShell transcription is enabled by policy on this machine." -ForegroundColor Red
	Write-Host "       Policy key  : $($transcription.Key)"
	if ($transcription.Directory) {
		Write-Host "       Transcripts : $($transcription.Directory)"
	}
	Write-Host "       A generated password shown on screen would be written to the transcript file."
	Write-Host "       Change the password with another tool, or run this script again with -force" -ForegroundColor Yellow
	Write-Host "       if the transcript is acceptable and will be handled as a secret." -ForegroundColor Yellow
	exit 3
}

if ($mode -eq "ask" -and $transcription) {
	Write-Host "NOTE: PowerShell transcription is enabled, but a typed password is never echoed" -ForegroundColor Yellow
	Write-Host "      and does not reach the transcript. Only the prompts do." -ForegroundColor Yellow
}

$exists = $null -ne (Get-LocalUser -Name $username -ErrorAction SilentlyContinue)

if ($create -and $exists) {
	Write-Host "ERROR: The user $username already exists" -ForegroundColor Red
	exit 1
}

if (-not $create -and -not $exists) {
	Write-Host "ERROR: The user $username does not exist" -ForegroundColor Red
	exit 1
}

$generated = $null

if ($mode -eq "ask") {
	$first = Read-Host "Password for $username" -AsSecureString
	$again = Read-Host "Repeat the password" -AsSecureString

	if ((Read-SecureText $first) -cne (Read-SecureText $again)) {
		Write-Host "ERROR: The two passwords do not match, nothing was changed" -ForegroundColor Red
		exit 1
	}

	$secure = $first
}
else {
	$generated = New-Password $length
	$secure = ConvertTo-SecureString $generated -AsPlainText -Force
}

Try {
	if ($create) {
		[void](New-LocalUser -Name $username -Password $secure -AccountNeverExpires -ErrorAction Stop)
		Write-Host "User $username created, enabled and with no expiration date"
	}
	else {
		Set-LocalUser -Name $username -Password $secure -AccountNeverExpires -ErrorAction Stop
		Enable-LocalUser -Name $username -ErrorAction Stop
		Write-Host "Password of $username changed, account enabled and with no expiration date"
	}
}
Catch {
	Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
	exit 1
}

$account = Get-LocalUser -Name $username
Write-Host ("Enabled: {0}   Account expires: {1}" -f $account.Enabled, $(if ($null -eq $account.AccountExpires) { "never" } else { $account.AccountExpires }))

if ($generated) {
	Write-Host ""
	Write-Host "  $generated" -ForegroundColor Green
	Write-Host ""
	Write-Host "Copy it into the password manager now. It is shown once and stored nowhere." -ForegroundColor Yellow
	[void](Read-Host "Press Enter once it is saved")
	Clear-Host
	Write-Host "Password of $username changed. The console has been cleared."
}

exit 0
