# ============================================================
#  hid-generator.ps1
#  Prints the hardware identifier of this machine: the SHA-256
#  of the BIOS serial, the processor id, the MAC addresses of
#  the physical adapters and the serial numbers of the memory
#  modules and the disks. One line on standard output, and
#  nothing else, because the caller captures it with for /f.
#
#  THERE IS NO SALT, and there never was: this script takes no
#  argument but -Verbose. A second word typed after
#  cats create Machine used to land in $args and be dropped in
#  silence; with [CmdletBinding()] it is now refused instead.
#
#  -Verbose, or -v, walks through what goes into the hash. It
#  writes to the verbose stream and not to standard output, so a
#  caller capturing the identifier still captures the identifier
#  alone - which the switch it replaces did not do.
# ============================================================

[CmdletBinding()]
param()

# An unhandled error used to leave the caller with a bare exit code and no reason to
# read. Every helper of this repository answers the same way since 2026-09-22.
trap {
	Write-Host ("ERROR     : hid-generator failed: " + $_.Exception.Message + " [line " + $_.InvocationInfo.ScriptLineNumber + "]") -ForegroundColor Red
	exit 1
}

# BIOS/UEFI
$bios = ((Get-WmiObject Win32_BIOS).SerialNumber).Trim()
Write-Verbose "BIOS/UEFI ID:  $bios"

# CPU
$cpu = ((Get-WmiObject Win32_Processor).ProcessorId).Trim()
Write-Verbose "CPU ID:        $cpu"

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
Write-Verbose "NETs ID:       $netsid"


$ramInfo = Get-WmiObject Win32_PhysicalMemory | ForEach-Object {
	"$($_.SerialNumber)-$($_.PartNumber)"
}
$ramID = (($ramInfo | Sort-Object) -join "|").Trim()
Write-Verbose "RAM    :       $ramID"

$diskSerials = ((Get-WmiObject Win32_PhysicalMedia | ForEach-Object { $_.SerialNumber }) -join "|").Trim()
Write-Verbose "HDD/SSD:       $diskSerials"

# Raw String
$raw = "$bios|$cpu|$netsid|$ramID|$diskSerials"
Write-Verbose "RAW ID STRING: $raw"

# Hash SHA-256
$uidBytes = [System.Text.Encoding]::UTF8.GetBytes($raw)
$sha256 = [System.Security.Cryptography.SHA256]::Create()
$hash = $sha256.ComputeHash($uidBytes)
$hid = [System.BitConverter]::ToString($hash).Replace("-", "")

# Output: the identifier alone, always. What -Verbose adds went to the verbose stream
Write-Verbose "HID:           $hid"
Write-Output $hid
