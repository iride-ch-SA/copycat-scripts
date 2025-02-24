@echo off
setlocal enabledelayedexpansion

or %%a in (%*) do (
	f /I "%%a"=="template" (
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
		REM **** Install Intel Driver and Support Assistant
		winget install Intel.IntelDriverAndSupportAssistant --accept-package-agreements --accept-source-agreements		
	)
)
