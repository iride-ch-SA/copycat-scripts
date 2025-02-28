@echo off
setlocal enabledelayedexpansion

for %%a in (%*) do (
	if /I "%%a"=="template" (
		REM **** Install Acronis Agent
		powershell -command "(new-object System.Net.WebClient).DownloadFile('https://storage.googleapis.com/01931185-232c-77a5-8e67-8751490ebf3e/CopyCats/AcronisSnapDeployAgent64.msi','C:\Admin\Installers\AcronisSnapDeployAgent64.msi')"
		C:\Admin\Installers\AcronisSnapDeployAgent64.msi /quiet
	)
	
	if /I "%%a"=="base" (
		REM **** Install Destination Softwares
		winget install Google.Chrome --accept-package-agreements --accept-source-agreements
		winget install Mozilla.Firefox --accept-package-agreements --accept-source-agreements
		winget install Adobe.Acrobat.Reader.64-bit --accept-package-agreements --accept-source-agreements
		winget install VideoLAN.VLC --accept-package-agreements --accept-source-agreements
		
		REM *** Install Office via Deployment Tool
		winget install Microsoft.OfficeDeploymentTool --accept-package-agreements --accept-source-agreements
		"C:\Program Files\OfficeDeploymentTool\setup.exe" /configure C:\Admin\Scripts\config\office.xml
	)
	
	if /I "%%a"=="support" (
		REM **** Install Remote Support tool
		REM *** Download fresh version of Support Assistant Tool
		powershell -command "(new-object System.Net.WebClient).DownloadFile('https://storage.googleapis.com/01931185-232c-77a5-8e67-8751490ebf3e/SupportoIT/supportoit.exe','C:\Admin\Apps\supportoit.exe')"
		
		REM *** Create Shortcut for all Users
		Powershell -command "New-Item -ItemType SymbolicLink -Path 'C:\Users\Public\Desktop' -Name 'Supporto IT' -Value 'C:\Admin\Apps\supportoit.exe'"
	)
	
	if /I "%%a"=="intelnuc" (
		winget install Intel.IntelDriverAndSupportAssistant --accept-package-agreements --accept-source-agreements		
	)
	
	if /I "%%a"=="nuc13ANx-drivers" (
		powershell -command "(new-object System.Net.WebClient).DownloadFile('https://dlcdnets.asus.com/pub/ASUS/NUC/NUC_13_Pro_Kit/NUC13AN_LC_non-Vpro_INF_Pack_8_23_2024.zip','C:\Admin\Drivers\NUC_Drivers.zip')"
		powershell -command "Expand-Archive -Path 'C:\Admin\Drivers\NUC_Drivers.zip' -DestinationPath 'C:\Admin\Drivers\NUC_Drivers' -Force"	
	)
	
	if /I "%%a"=="windowsapp" (
		powershell -noprofile -executionpolicy bypass -command "C:\Admin\Scripts\ps\install-user-avd.ps1"
	)
	
	if /I "%%a"=="google-workspace" (
		winget install Google.GoogleDrive --accept-package-agreements --accept-source-agreements
		powershell -command "(new-object System.Net.WebClient).DownloadFile('https://dl.google.com/dl/google-apps-sync/x64/enterprise_gsync.msi','C:\Admin\Installers\enterprise_gsync.msi')"
		C:\Admin\Installers\enterprise_gsync.msi
	)
)
