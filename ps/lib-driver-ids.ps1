# ============================================================
#  lib-driver-ids.ps1
#  Not a script to run: the library the two driver scripts of
#  this repository dot-source, holding the one question both of
#  them have to answer the same way - does this driver package
#  know about this device?
#    . (Join-Path $PSScriptRoot 'lib-driver-ids.ps1')
#  Get-DeviceIds        : the ids a device enumerates with, the
#                         ones naming only a vendor or only a
#                         device class left out
#  Get-InfFacts         : the hardware ids an .inf claims, the
#                         architectures it has sections for and
#                         whether it is an extension, read in one
#                         pass over the file
#  Test-IdMatch         : do two of those ids name the same part
#  Get-DriverMatches    : the above over a whole library - which
#                         package fits which device, which device
#                         nothing fits, and which is claimed by an
#                         extension alone, which is the same as
#                         nothing
#
#  driver-scan.ps1 installs what fits; asus-driver-fetch.ps1 asks
#  whether the vendor catalogue still owes this machine
#  something. If the two answered that question differently the
#  fetch would stop while a device is still unclaimed, which is
#  the case this library was pulled out for: on a NUC15CRBC5 the
#  catalogue has no Audio group at all and the audio controller
#  is only inside the family INF pack, so "nothing here fits this
#  device" is what has to send the fetch back to the catalogue.
# ============================================================

# The ids are read out of the whole .inf rather than by walking [Manufacturer] into its model
# sections. An inf is a small file and the ids are written in it literally; a real parser would
# have to honour the decoration suffixes and resolve %strings%, and it would buy nothing here -
# the question asked is "does this package know about this device", not "which install section
# would Windows pick". That second one is pnputil's, and pnputil is what installs.
$script:InfIdPattern = '(?i)\b(?:PCI|USB|USBPRINT|HID|ACPI|HDAUDIO|INTELAUDIO|SWC|SW|ROOT|SD|MMC|SCSI|IDE|UMB|BTH|BTHENUM|BTHLE|MONITOR|DISPLAY|PCMCIA|WSDPRINT|NET|VEN|WPDBUSENUM|UEFI)\\[A-Z0-9_&.\-+{}]{4,}'

# A device does not enumerate with the id of the part alone: the bus driver hangs a ladder of
# compatible ids under it, and the last rung of the PCI one is the vendor by itself. PCI\VEN_8086
# sits on every Intel device of the board, and every .inf that names any Intel part begins with
# those same twelve characters - so an id that stops at the vendor, or at the device class,
# matches everything and therefore says nothing. Kept in the match, they make every package of a
# vendor fit every device of that vendor.
$script:GenericIdPatterns = @(
	'^PCI\\VEN_[0-9A-F]{4}$',
	'^PCI\\VEN_[0-9A-F]{4}&CC_[0-9A-F]{4,6}$',
	'^PCI\\CC_[0-9A-F]{4,6}$',
	'^USB\\CLASS_[0-9A-F]{2}(&SUBCLASS_[0-9A-F]{2})?(&PROT_[0-9A-F]{2})?$',
	'^USB\\COMPOSITE$',
	'^HID_DEVICE'
)

function Test-IdTooGeneric([string]$id) {
	foreach ($pattern in $script:GenericIdPatterns) {
		if ($id -match $pattern) { return $true }
	}
	return $false
}

function Get-DeviceIds([string]$instanceId) {
	# Hardware ids first, compatible ids after: both are asked for because a device whose exact
	# part nothing claims is often still served by a package written for the generation it
	# belongs to, and that match happens on a compatible id. The generic rungs are dropped here
	# rather than at the comparison, so that every caller gets the same list.
	$ids = @()
	foreach ($key in @('DEVPKEY_Device_HardwareIds', 'DEVPKEY_Device_CompatibleIds')) {
		try {
			$property = Get-PnpDeviceProperty -InstanceId $instanceId -KeyName $key -ErrorAction Stop
			if ($null -ne $property -and $null -ne $property.Data) { $ids += @($property.Data) }
		} catch {
			# A device may carry neither list; that is not a failure of the scan
		}
	}
	return @($ids |
		Where-Object { $_ } |
		ForEach-Object { $_.ToString().Trim().ToUpperInvariant() } |
		Where-Object { $_.Length -gt 0 -and -not (Test-IdTooGeneric $_) } |
		Select-Object -Unique)
}

# The two ids match when they are the same id, or when one is the other cut short at a field
# boundary - that is how Windows ranks a driver written for PCI\VEN_8086&DEV_A0F0 against a
# device that enumerates as PCI\VEN_8086&DEV_A0F0&SUBSYS_89C61028&REV_11. The boundary matters:
# a plain StartsWith would let PCI\VEN_8086&DEV_A0F match the device above and it is a different
# part. Both directions are kept - an OEM inf naming a SUBSYS the device only carries on its
# hardware id is the mirror case - and both are safe now that the ids naming a bare vendor are
# out of the device list.
function Test-IdMatch([string]$deviceId, [string]$infId) {
	if ($infId.Length -lt 8 -or $deviceId.Length -lt 8) { return $false }
	if ($deviceId -eq $infId) { return $true }
	if ($deviceId.StartsWith($infId) -and $deviceId.Substring($infId.Length).StartsWith('&')) { return $true }
	if ($infId.StartsWith($deviceId) -and $infId.Substring($deviceId.Length).StartsWith('&')) { return $true }
	return $false
}

# What [Manufacturer] says after the models section is the decoration, NTamd64 and friends, and
# it is the only place an inf declares what it can be installed on. An inf with no decoration at
# all is the legacy form and applies everywhere, so it is kept.
function Get-InfDecorations([string]$text) {
	$decorations = @()
	$inSection = $false
	foreach ($raw in ($text -split "`r?`n")) {
		$line = $raw.Trim()
		if ($line.StartsWith('[')) {
			$inSection = ($line -match '^\[\s*Manufacturer\s*\]')
			continue
		}
		if (-not $inSection) { continue }
		$line = ($line -split ';')[0].Trim()
		if ([string]::IsNullOrWhiteSpace($line)) { continue }
		$position = $line.IndexOf('=')
		if ($position -lt 0) { continue }
		$fields = @($line.Substring($position + 1) -split ',')
		# field 0 is the models section, everything after it is one decoration
		for ($index = 1; $index -lt $fields.Count; $index++) {
			$decoration = $fields[$index].Trim().ToUpperInvariant()
			if ($decoration) { $decorations += $decoration }
		}
	}
	return @($decorations | Select-Object -Unique)
}

# An extension .inf does not install a device, it adds settings on top of the package that does:
# Class=Extension, its own ClassGuid, and an ExtensionId. Windows stages it and even reports it as
# updated on the device, and the device stays without a driver, because an extension has none to
# give. A device claimed by an extension alone is therefore a device nothing can serve.
function Test-InfIsExtension([string]$text) {
    if ($text -match '(?im)^\s*ExtensionId\s*=') { return $true }
    if ($text -match '(?im)^\s*Class\s*=\s*Extension\b') { return $true }
    if ($text -match '(?i)\{e2f84ce7-8efa-411c-aa69-97454ca4cb57\}') { return $true }
    return $false
}

function Get-HostArchitecture {
	# ARCHITEW6432 first: inside a 32 bit PowerShell on a 64 bit Windows, PROCESSOR_ARCHITECTURE
	# says x86 and would have this machine install x86 packages on itself
	$architecture = $env:PROCESSOR_ARCHITEW6432
	if ([string]::IsNullOrWhiteSpace($architecture)) { $architecture = $env:PROCESSOR_ARCHITECTURE }
	switch (([string]$architecture).Trim().ToUpperInvariant()) {
		'AMD64' { return 'NTAMD64' }
		'ARM64' { return 'NTARM64' }
		'X86'   { return 'NTX86' }
		# An architecture this does not know is not a reason to install nothing
		default { return '' }
	}
}

# The library is read once per file and kept: cats install Drivers walks it several times in one
# run - a bus driver in charge enumerates children that were not there a minute earlier - and the
# library does not change between those passes.
$script:InfFactsCache = @{}

function Get-InfFacts([string]$file) {
	# Keyed by size and write time as well as by path: cats prepare Drivers force re-fetches a
	# package over the one that is there, and the same path can hold a different file between two
	# calls of the same run
	$key = $file
	try {
		$info = Get-Item -LiteralPath $file -ErrorAction Stop
		$key = "$file|$($info.Length)|$($info.LastWriteTimeUtc.Ticks)"
	} catch {
		# Unreadable here means unreadable below too, and the path alone will do as a key
	}
	if ($script:InfFactsCache.ContainsKey($key)) { return $script:InfFactsCache[$key] }
	$facts = [pscustomobject]@{ File = $file; Ids = @(); Decorations = @(); IsExtension = $false; Read = $false }
	$text = ''
	try {
		$text = Get-Content -LiteralPath $file -Raw -ErrorAction Stop
	} catch {
		$script:InfFactsCache[$key] = $facts
		return $facts
	}
	if ([string]::IsNullOrWhiteSpace($text)) { $script:InfFactsCache[$key] = $facts; return $facts }
	$facts.Read = $true
	$found = @()
	foreach ($match in [regex]::Matches($text, $script:InfIdPattern)) {
		$found += $match.Value.Trim().TrimEnd(',', ';', '"').ToUpperInvariant()
	}
	$facts.Ids = @($found | Select-Object -Unique)
	$facts.Decorations = Get-InfDecorations $text
	$facts.IsExtension = Test-InfIsExtension $text
	$script:InfFactsCache[$key] = $facts
	return $facts
}

function Test-InfFitsArchitecture($facts, [string]$architecture) {
	if ([string]::IsNullOrWhiteSpace($architecture)) { return $true }
	if ($null -eq $facts -or $facts.Decorations.Count -eq 0) { return $true }
	foreach ($decoration in $facts.Decorations) {
		if ($decoration -eq $architecture) { return $true }
		if ($decoration.StartsWith($architecture + '.')) { return $true }
	}
	return $false
}

# ---- the library against the devices ----
#
# $Devices are objects with a Name, an InstanceId and an Ids list - what Get-DeviceIds returned
# for them. The answer carries both halves of the question: what fits, and what is still
# unclaimed. The second one is the one that decides whether there is anything left to fetch.
function Get-DriverMatches {
	param(
		[string]$Path,
		$Devices,
		[string]$Architecture = ''
	)

	$result = [pscustomobject]@{
		Relevant          = @()
		InfCount          = 0
		OtherArchitecture = 0
		Unreadable        = 0
		Uncovered         = @()
		ExtensionOnly     = @()
	}

	if (-not (Test-Path -LiteralPath $Path)) {
		$result.Uncovered = @($Devices)
		return $result
	}

	$infFiles = @(Get-ChildItem -LiteralPath $Path -Filter '*.inf' -Recurse -File -ErrorAction SilentlyContinue)
	$result.InfCount = $infFiles.Count

	$covered = @{}
	$byExtension = @{}
	$relevant = @()
	foreach ($inf in $infFiles) {
		$facts = Get-InfFacts $inf.FullName
		if (-not $facts.Read) { $result.Unreadable++; continue }
		if ($facts.Ids.Count -eq 0) { continue }
		# A package for another architecture is staged by pnputil without a complaint and serves
		# no device here, so it is not offered to it
		if (-not (Test-InfFitsArchitecture $facts $Architecture)) { $result.OtherArchitecture++; continue }

		$matched = @()
		foreach ($device in $Devices) {
			foreach ($deviceId in $device.Ids) {
				$hit = $false
				foreach ($infId in $facts.Ids) {
					if (Test-IdMatch $deviceId $infId) { $hit = $true; break }
				}
				if ($hit) {
					$matched += $device.Name
					# An extension claims the device without being able to serve it, so it does not
					# cover it: counted apart, and the device stays in the list of what is missing
					if ($facts.IsExtension) { $byExtension[[string]$device.InstanceId] = $true }
					else { $covered[[string]$device.InstanceId] = $true }
					break
				}
			}
		}
		if ($matched.Count -gt 0) {
			$relevant += [pscustomobject]@{ File = $inf.FullName; Devices = @($matched | Select-Object -Unique); IsExtension = $facts.IsExtension }
		}
	}

	$result.Relevant = @($relevant)
	# Keyed by instance id and not by name: a machine with three unknown devices calls all three
	# of them "Dispositivo PCI", and two of them would be reported as covered by the first
	$result.Uncovered = @($Devices | Where-Object { -not $covered.ContainsKey([string]$_.InstanceId) })
	# The ones an operator would otherwise be told nothing about: something does claim them, and it
	# is a package that cannot serve them
	$result.ExtensionOnly = @($result.Uncovered | Where-Object { $byExtension.ContainsKey([string]$_.InstanceId) })
	return $result
}
