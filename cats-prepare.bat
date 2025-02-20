@echo off

REM **** Update Scripts
git --git-dir="C:\Admin\Scripts\.git" --work-tree="C:\Admin\Scripts" pull

REM **** Consent Powershell Scripts
powershell -Command "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force"

REM **** Create Standard IT Admin folders in C:
mkdir C:\Admin
mkdir C:\Admin\Apps
mkdir C:\Admin\Drivers
mkdir C:\Admin\Installers
mkdir C:\Admin\Others

REM **** Add Apps
C:\Users\itadmin>winget install Microsoft.Sysinternals.BGInfo --location C:\Admin\Apps\

REM **** Disable Widgets in menu bar (for all users)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /t REG_DWORD /v AllowNewsAndInterests /d "0" /f

C:\Admin\Scripts\reset-power-settings.bat

REM **** Install Destination Softwares
C:\Admin\Scripts\install-destination-softwares.bat template base support 

REM **** Install Powershell Windows Updates tool
powershell -command "Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force"
powershell -command "Install-Module PSWindowsUpdate -Force"
powershell -command "Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted"
