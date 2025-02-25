@echo off

REM **** Consent Powershell Scripts
powershell -Command "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

for %%a in (%*) do (
	if /I "%%a"=="scripts" (
		REM **** Updates Scripts
		git --git-dir="C:\Admin\Scripts\.git" --work-tree="C:\Admin\Scripts" pull
		setx PATH "%PATH%;C:\Admin\Scripts" /M
	)
	
	if /I "%%a"=="admin-folders" (
		REM **** Create Standard IT Admin folders in C:
		mkdir C:\Admin
		mkdir C:\Admin\Apps
		mkdir C:\Admin\Drivers
		mkdir C:\Admin\Installers
		mkdir C:\Admin\Others
	)
	
	if /I "%%a"=="utils" (
		REM **** Add Apps
		C:\Users\itadmin>winget install Microsoft.Sysinternals.BGInfo --location C:\Admin\Apps\
		icacls "C:\Admin\Apps\bginfo.exe" /grant Users:(RX)
		
		REM **** Install Destination Softwares
		C:\Admin\Scripts\install-destination-softwares.bat template base support 
		
		REM **** Set a sagerun:1 (TODO: create REGISTRY ADD to do unattended)
		cleanmgr /sageset:1
	)
	
	if /I "%%a"=="systailoring" (
		REM **** Disable Widgets in menu bar (for all users)
		reg add "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /t REG_DWORD /v AllowNewsAndInterests /d "0" /f
		
		C:\Admin\Scripts\reset-power-settings.bat
	)
	
	if /I "%%a"=="win-updates" (
		REM **** Install Powershell Windows Updates tool
		powershell -command "Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force"
		powershell -command "Install-Module PSWindowsUpdate -Force"
		powershell -command "Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted"
	)
	
	if /I "%%a"=="deploy-azure" (
		REM **** Show AAD Users on Login Screen
		reg add "HKLM\Software\Policies\Microsoft\Windows\System" /t REG_DWORD /v EnumerateLocalUsers /d "1" /f
		reg delete "HKLM\Software\Policies\Microsoft\Windows\System" /v DontEnumerateConnectedUsers /f
		reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /t REG_DWORD /v dontdisplaylastusername /d "0" /f
		
		REM **** Hide itadmin from Login Screen
		reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" /t REG_DWORD /f /d 0 /v itadmin
	)
)
