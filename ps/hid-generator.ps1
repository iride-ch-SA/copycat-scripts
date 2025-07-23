param (
	[Alias("v")]
	[switch]$Verbose
)

# BIOS/UEFI
$bios = ((Get-WmiObject Win32_BIOS).SerialNumber).Trim()
if ($Verbose) { Write-Output "BIOS/UEFI ID:  $bios" }

# CPU
$cpu = ((Get-WmiObject Win32_Processor).ProcessorId).Trim()
if ($Verbose) { Write-Output "CPU ID:        $cpu" }

# Physical Network Adapters
$physicalAdapters = Get-WmiObject Win32_NetworkAdapter |
	Where-Object {
		$_.PhysicalAdapter -eq $true -and
		$_.MACAddress -ne $null -and
		$_.Manufacturer -notmatch "Microsoft" -and
		$_.Name -notmatch "Virtual|Loopback|VPN|TAP|Pseudo"
	}

$macs = $physicalAdapters | Select-Object -ExpandProperty MACAddress
$netsid = (($macs | Sort-Object) -join "|").Trim()
if ($Verbose) { Write-Output "NETs ID:       $netsid" }


$ramInfo = Get-WmiObject Win32_PhysicalMemory | ForEach-Object {
	"$($_.SerialNumber)-$($_.PartNumber)"
}
$ramID = (($ramInfo | Sort-Object) -join "|").Trim()
if ($Verbose) { Write-Output "RAM    :       $ramID" }

$diskSerials = ((Get-WmiObject Win32_PhysicalMedia | ForEach-Object { $_.SerialNumber }) -join "|").Trim()
if ($Verbose) { Write-Output "HDD/SSD:       $diskSerials" }

# Raw String
$raw = "$bios|$cpu|$netsid|$ramID|$diskSerials"
if ($Verbose) { Write-Output "RAW ID STRING: $raw" }

# Hash SHA-256
$uidBytes = [System.Text.Encoding]::UTF8.GetBytes($raw)
$sha256 = [System.Security.Cryptography.SHA256]::Create()
$hash = $sha256.ComputeHash($uidBytes)
$hid = [System.BitConverter]::ToString($hash).Replace("-", "")

# Output 
if ($Verbose) {
	Write-Output "HID:           $hid"
} else {
	Write-Output $hid
}
