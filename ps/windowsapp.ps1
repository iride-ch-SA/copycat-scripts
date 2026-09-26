# ============================================================
#  windowsapp.ps1
#  Windows App, the Remote Desktop and Windows 365 client, for
#  every user of the machine. Two halves, as for PaperCut Hive:
#
#  -Machine, from an elevated prompt, after winget has installed
#  the package with --scope machine. It checks that the package
#  is provisioned, which is what makes Windows register it in
#  every profile, those created later included, and provisions
#  it itself when winget did not: winget install finds the app
#  already registered for the administrator, goes on to upgrade
#  it, and an upgrade with nothing newer provisions nothing. The
#  package is already on the machine then, so it is provisioned
#  by its family name, with the same call winget makes,
#  PackageManager.ProvisionPackageForAllUsersAsync, and nothing
#  is downloaded again. Then it pins the app to the taskbar of
#  the profiles created from now on (see THE TASKBAR).
#
#  Without -Machine, at every sign in, as the user: the net
#  under the provisioning. If the app is not registered for the
#  user it is registered from the package already on the machine,
#  Add-AppxPackage -RegisterByFamilyName: no administrator, no
#  download, a few seconds. It is what reaches the profiles that
#  existed before the package was provisioned. If the package is
#  not on the machine it says so and stops: it does not install
#  the app per user with winget, because a per user install is
#  what this script exists to replace, and at a first sign in
#  winget may not be registered yet.
#
#  THE TASKBAR. Windows 11 takes the taskbar pins of a new
#  profile from LayoutModification.xml in the Default profile,
#  AppData\Local\Microsoft\Windows\Shell, at its first sign in.
#  Only new profiles: an existing profile is not touched, and
#  the user may unpin the app. The pin is a taskbar:UWA element
#  in a CustomTaskbarLayoutCollection without PinListPlacement,
#  so the default pins of Windows stay and the app comes after
#  them. The file is not a policy: nothing is written under
#  Policies, which the Start layout policy would do and which
#  cats clean Microsoft.Windows keeps away from. A file already
#  there is not replaced: the pin is added to its pin lists, and
#  the original is kept once as LayoutModification.xml.cats-bak.
#  The AppUserModelID is not written here by hand: it is the
#  family name, an exclamation mark and the Id of the application
#  in the AppxManifest.xml of the package on this machine.
#
#  Parameters:
#    -Machine            provision and pin, elevated
#    -Name <name>        the package name,
#                        MicrosoftCorporationII.Windows365
#    -Family <family>    its family name,
#                        MicrosoftCorporationII.Windows365_8wekyb3d8bbwe
#    -DefaultProfile <p> the Default profile, read from the
#                        registry when not given
#
#  Exit codes, at sign in: 0 the app is registered for the user,
#  now or before; 2 it is not, and the reason is on the console;
#  7 the script runs as SYSTEM; 8 an unexpected error.
#  With -Machine: 0 provisioned and pinned; 2 not provisioned;
#  4 provisioned, the taskbar pin not written; 8 an unexpected
#  error; 9 the prompt is not elevated.
# ============================================================

[CmdletBinding()]
param(
	[switch]$Machine,
	[string]$Name = 'MicrosoftCorporationII.Windows365',
	[string]$Family = 'MicrosoftCorporationII.Windows365_8wekyb3d8bbwe',
	[string]$DefaultProfile = ''
)

$ErrorActionPreference = 'Stop'

function Write-Recipe([string]$text) { Write-Host ("RECIPE    : " + $text) -ForegroundColor Cyan }
function Write-Done([string]$text)   { Write-Host ("RECIPE    : " + $text) -ForegroundColor Green }
function Write-Warn([string]$text)   { Write-Host ("WARNING   : " + $text) -ForegroundColor Yellow }
function Write-Fail([string]$text)   { Write-Host ("ERROR     : " + $text) -ForegroundColor Red }
function Write-Plain([string]$text)  { Write-Host ("            " + $text) }

trap {
	Write-Fail "windowsapp failed: $($_.Exception.Message) [line $($_.InvocationInfo.ScriptLineNumber)]"
	exit 8
}

$nsLayout   = 'http://schemas.microsoft.com/Start/2014/LayoutModification'
$nsDefault  = 'http://schemas.microsoft.com/Start/2014/FullDefaultLayout'
$nsStart    = 'http://schemas.microsoft.com/Start/2014/StartLayout'
$nsTaskbar  = 'http://schemas.microsoft.com/Start/2014/TaskbarLayout'

# True when the package is provisioned on this machine
function Test-Provisioned {
	$found = @(Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $Name })
	return ($found.Count -gt 0)
}

# Provisions a package already on the machine by its family name, the call winget
# makes for an msix in machine scope. It is a WinRT call, awaited through AsTask,
# which Windows PowerShell can reach and PowerShell 7 cannot
function Invoke-Provision {
	if ($PSVersionTable.PSEdition -eq 'Core') {
		Write-Warn 'the package cannot be provisioned from PowerShell 7: run this with powershell.exe'
		return $false
	}
	Add-Type -AssemblyName System.Runtime.WindowsRuntime
	$null = [Windows.Management.Deployment.PackageManager, Windows.Management.Deployment, ContentType = WindowsRuntime]
	$asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
		$_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetGenericArguments().Count -eq 2 -and $_.GetParameters().Count -eq 1
	} | Select-Object -First 1
	$asTask = $asTask.MakeGenericMethod([Windows.Management.Deployment.DeploymentResult], [Windows.Management.Deployment.DeploymentProgress])
	$operation = (New-Object Windows.Management.Deployment.PackageManager).ProvisionPackageForAllUsersAsync($Family)
	$task = $asTask.Invoke($null, @($operation))
	try {
		if (-not $task.Wait(300000)) {
			Write-Fail 'the provisioning did not end within 5 minutes'
			return $false
		}
	} catch {
		$inner = $_.Exception
		while ($inner.InnerException) { $inner = $inner.InnerException }
		Write-Fail ('the provisioning was refused: ' + $inner.Message)
		return $false
	}
	return $true
}

# The AppUserModelID of the app, from the manifest of the package on this machine.
# Null, and said why, when it cannot be read
function Get-AppId {
	$package = Get-AppxPackage -AllUsers -Name $Name | Sort-Object { [version]$_.Version } -Descending | Select-Object -First 1
	if (-not $package) {
		Write-Warn "$Name is provisioned but not on the machine for any user, its manifest cannot be read"
		return $null
	}
	$manifestPath = Join-Path $package.InstallLocation 'AppxManifest.xml'
	try {
		[xml]$manifest = Get-Content -LiteralPath $manifestPath -Raw
	} catch {
		Write-Warn ("$manifestPath cannot be read: " + $_.Exception.Message)
		return $null
	}
	$ids = @($manifest.Package.Applications.Application | ForEach-Object { $_.Id } | Where-Object { $_ })
	if ($ids.Count -eq 0) {
		Write-Warn "$manifestPath names no application"
		return $null
	}
	if ($ids.Count -gt 1) {
		Write-Warn ('the package has ' + $ids.Count + ' applications, the first is pinned: ' + ($ids -join ', '))
	}
	return ($package.PackageFamilyName + '!' + $ids[0])
}

# The Default profile, from the registry unless it was given
function Get-DefaultProfile {
	if ($DefaultProfile) { return $DefaultProfile }
	$value = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList' -Name 'Default').Default
	return [Environment]::ExpandEnvironmentVariables($value)
}

# Adds the pin to LayoutModification.xml of the Default profile, writing the file
# if it is not there. True when the pin is in the file, now or before
function Set-TaskbarPin([string]$appId) {
	$shell = Join-Path (Get-DefaultProfile) 'AppData\Local\Microsoft\Windows\Shell'
	$layout = Join-Path $shell 'LayoutModification.xml'

	if (-not (Test-Path -LiteralPath $layout)) {
		if (-not (Test-Path -LiteralPath $shell)) { New-Item -ItemType Directory -Path $shell | Out-Null }
		$text = @(
			'<?xml version="1.0" encoding="utf-8"?>'
			('<LayoutModificationTemplate xmlns="' + $nsLayout + '"')
			('    xmlns:defaultlayout="' + $nsDefault + '"')
			('    xmlns:start="' + $nsStart + '"')
			('    xmlns:taskbar="' + $nsTaskbar + '"')
			'    Version="1">'
			'  <CustomTaskbarLayoutCollection>'
			'    <defaultlayout:TaskbarLayout>'
			'      <taskbar:TaskbarPinList>'
			('        <taskbar:UWA AppUserModelID="' + $appId + '" />')
			'      </taskbar:TaskbarPinList>'
			'    </defaultlayout:TaskbarLayout>'
			'  </CustomTaskbarLayoutCollection>'
			'</LayoutModificationTemplate>'
		) -join "`r`n"
		[IO.File]::WriteAllText($layout, $text + "`r`n", (New-Object Text.UTF8Encoding $false))
		Write-Done "$layout written: new profiles get Windows App on the taskbar"
		return $true
	}

	[xml]$doc = Get-Content -LiteralPath $layout -Raw
	$ns = New-Object Xml.XmlNamespaceManager $doc.NameTable
	$ns.AddNamespace('lm', $nsLayout)
	$ns.AddNamespace('defaultlayout', $nsDefault)
	$ns.AddNamespace('taskbar', $nsTaskbar)

	if ($doc.SelectSingleNode("//taskbar:UWA[@AppUserModelID='$appId']", $ns)) {
		Write-Warn "$layout already pins Windows App and was left as it is"
		return $true
	}
	$root = $doc.SelectSingleNode('/lm:LayoutModificationTemplate', $ns)
	if (-not $root) {
		Write-Warn "$layout is not a LayoutModificationTemplate and was left as it is"
		return $false
	}

	$lists = @($doc.SelectNodes('//taskbar:TaskbarPinList', $ns))
	if ($lists.Count -eq 0) {
		$collection = $doc.CreateElement('CustomTaskbarLayoutCollection', $nsLayout)
		$taskbarLayout = $doc.CreateElement('defaultlayout', 'TaskbarLayout', $nsDefault)
		$list = $doc.CreateElement('taskbar', 'TaskbarPinList', $nsTaskbar)
		[void]$taskbarLayout.AppendChild($list)
		[void]$collection.AppendChild($taskbarLayout)
		[void]$root.AppendChild($collection)
		$lists = @($list)
	}
	foreach ($list in $lists) {
		$pin = $doc.CreateElement('taskbar', 'UWA', $nsTaskbar)
		$pin.SetAttribute('AppUserModelID', $appId)
		[void]$list.AppendChild($pin)
	}

	$backup = $layout + '.cats-bak'
	if (-not (Test-Path -LiteralPath $backup)) { Copy-Item -LiteralPath $layout -Destination $backup }
	$settings = New-Object Xml.XmlWriterSettings
	$settings.Indent = $true
	$settings.Encoding = New-Object Text.UTF8Encoding $false
	$writer = [Xml.XmlWriter]::Create($layout, $settings)
	try { $doc.Save($writer) } finally { $writer.Close() }
	Write-Done "$layout already existed: Windows App added to its taskbar pins, the original is in $backup"
	return $true
}

# The machine half, elevated
if ($Machine) {
	$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
	if (-not (New-Object Security.Principal.WindowsPrincipal $identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
		Write-Fail 'Windows App is provisioned from an elevated prompt'
		exit 9
	}

	if (Test-Provisioned) {
		Write-Done "$Name is provisioned: every profile gets it, those created later included"
	} else {
		Write-Recipe "$Name is not provisioned: provisioning the package already on the machine"
		if (-not (Invoke-Provision)) {
			Write-Fail "$Name is not provisioned, the reason is on the lines above"
			exit 2
		}
		if (-not (Test-Provisioned)) {
			Write-Fail "the provisioning ended without an error, but $Name is still not provisioned"
			exit 2
		}
		Write-Done "$Name provisioned: every profile gets it, those created later included"
	}

	$appId = Get-AppId
	if (-not $appId) { exit 4 }
	Write-Recipe "the AppUserModelID of Windows App is $appId"
	if (-not (Set-TaskbarPin $appId)) { exit 4 }
	exit 0
}

# The sign in half, as the user, never SYSTEM
if ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value -eq 'S-1-5-18') {
	Write-Fail 'this runs as SYSTEM, and Windows App is registered per user'
	exit 7
}

if (Get-AppxPackage -Name $Name) {
	Write-Recipe 'Windows App is registered for this user'
	exit 0
}

Write-Recipe 'Windows App is not registered for this user: registering the package on the machine'
try {
	Add-AppxPackage -RegisterByFamilyName -MainPackage $Family
} catch {
	Write-Warn ('Windows App could not be registered: ' + $_.Exception.Message)
	Write-Plain 'if the package is not on the machine, an administrator runs cats install WindowsApp'
	exit 2
}

if (-not (Get-AppxPackage -Name $Name)) {
	Write-Warn 'the registration ended without an error, but Windows App is not registered for this user'
	exit 2
}
Write-Done 'Windows App registered for this user'
exit 0
