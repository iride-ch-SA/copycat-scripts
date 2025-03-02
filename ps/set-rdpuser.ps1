param(
	[string]$username
)

if (-not $username) {
	Write-Host "ERROR: Username expect as first parameter"  -ForegroundColor Red
	exit 1

}

# "Remote Desktop Users" universal SID is "S-1-5-32-555"
$remotedesktopgroup = Get-WmiObject Win32_Group | Where-Object { $_.SID -eq "S-1-5-32-555" } | Select-Object -ExpandProperty Name

if (-not $remotedesktopgroup) {
	Write-Host "ERROR: Remote Desktop User group not found at SID S-1-5-32-555." -ForegroundColor Red
	exit 1
}

Try {
	Add-LocalGroupMember -Group $remotedesktopgroup -Member $username -ErrorAction Stop
	Write-Host "User '$username' was added to Remote Desktop User group." -ForegroundColor Green
} Catch {
	Write-Host "ERROR: user '$username' cannot be added to Remote Desktop User group." -ForegroundColor Red
	Write-Host $_.Exception.Message
}
