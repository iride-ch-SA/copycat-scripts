@echo off
SET "PARAM=%~1"

REM **** Update Scripts
git --git-dir="C:\Admin\Scripts\.git" --work-tree="C:\Admin\Scripts" pull

REM **** Create Standard IT Admin folders in C:
mkdir C:\Admin
mkdir C:\Admin\Apps
mkdir C:\Admin\Drivers
mkdir C:\Admin\Installers
mkdir C:\Admin\Others

REM **** Disable Widgets in menu bar (for all users)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /t REG_DWORD /v AllowNewsAndInterests /d "0" /f

C:\Admin\Scripts\reset-power-settings.bat

IF /I "%PARAM%"=="template" (
	REM **** Install Acronis Agent
	powershell -command "(new-object System.Net.WebClient).DownloadFile('https://storage.googleapis.com/01931185-232c-77a5-8e67-8751490ebf3e/CopyCats/AcronisSnapDeployAgent64.msi','C:\Admin\Installers\AcronisSnapDeployAgent64.msi')"
	C:\Admin\Installers\AcronisSnapDeployAgent64.msi /quiet
)

REM **** Install Destination Softwares
winget install Google.Chrome --accept-package-agreements --accept-source-agreements
winget install Mozilla.Firefox --accept-package-agreements --accept-source-agreements
winget install Adobe.Acrobat.Reader.64-bit --accept-package-agreements --accept-source-agreements
winget install VideoLAN.VLC --accept-package-agreements --accept-source-agreements

REM *** Install Office via Deployment Tool
winget install Microsoft.OfficeDeploymentTool --accept-package-agreements --accept-source-agreements
"C:\Program Files\OfficeDeploymentTool\setup.exe" /configure C:\Admin\Scripts\office.xml

REM **** Install Remote Support tool
REM *** Download fresh version of Support Assistant Tool
powershell -command "(new-object System.Net.WebClient).DownloadFile('https://storage.googleapis.com/01931185-232c-77a5-8e67-8751490ebf3e/SupportoIT/supportoit.exe','C:\Admin\Apps\supportoit.exe')"

REM *** Create Shortcut for all Users
Powershell -command "New-Item -ItemType SymbolicLink -Path 'C:\Users\Public\Desktop' -Name 'Supporto IT' -Value 'C:\Admin\Apps\supportoit.exe'"

REM **** Install Powershell Windows Updates tool
powershell -command "Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force"
powershell -command "Install-Module PSWindowsUpdate -Force"
powershell -command "Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted"
