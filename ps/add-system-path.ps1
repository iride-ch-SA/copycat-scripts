param(
	[string]$folder
)

if (-not $folder) {
	Write-Host "ERROR: Folder expected as first parameter" -ForegroundColor Red
	exit 1
}

# The machine PATH is read from and written to the registry directly.
# setx must not be used here: it writes the process PATH, which is the merge of
# the system and the user variables, so it promotes the entries of the calling
# user to machine level. It also truncates any value longer than 1024 chars.
$environmentkey = "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
$folder = $folder.TrimEnd("\")

$key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($environmentkey, $true)

if (-not $key) {
	Write-Host "ERROR: Cannot open HKLM\$environmentkey for writing, run as Administrator." -ForegroundColor Red
	exit 1
}

Try {
	# DoNotExpandEnvironmentNames keeps entries such as %SystemRoot% unexpanded
	$currentpath = $key.GetValue("Path", "", [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
	$entries = $currentpath -split ";" | ForEach-Object { $_.Trim().TrimEnd("\") } | Where-Object { $_ -ne "" }

	if ($entries -contains $folder) {
		Write-Host "$folder is already in the system PATH, nothing to do"
		exit 0
	}

	# ExpandString writes REG_EXPAND_SZ, the type the system PATH must keep
	$key.SetValue("Path", (($entries + $folder) -join ";"), [Microsoft.Win32.RegistryValueKind]::ExpandString)
	Write-Host "$folder added to the system PATH"
}
Catch {
	Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
	exit 1
}
Finally {
	$key.Close()
}

# Without this broadcast a shell opened afterwards keeps the stale value
Try {
	Add-Type -Namespace Cats -Name Native -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
'@

	$broadcastresult = [UIntPtr]::Zero
	[void][Cats.Native]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, "Environment", 2, 5000, [ref]$broadcastresult)
}
Catch {
	Write-Host "WARNING: PATH updated but the change could not be broadcast, a logoff may be needed." -ForegroundColor Yellow
}

exit 0
