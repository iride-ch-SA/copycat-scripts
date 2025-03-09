@echo off
setlocal enabledelayedexpansion

echo [95mSTARTING [96m : CopyCat Prepare[0m

for %%a in (%*) do (
	if exist C:\Admin\Scripts\cats-recipes\%%a.bat ( 
		call C:\Admin\Scripts\cats-recipes\%%a.bat prepare
	) 

	if /I "%%a"=="utils" (
		echo [36mInstall Utilities[0m 

		echo [36m Install BGInfo from install-destination-softwares[0m 
		call C:\Admin\Scripts\install-destination-softwares.bat bginfo
		echo [36m Install Template from install-destination-softwares[0m
		call C:\Admin\Scripts\install-destination-softwares.bat template
		echo [36m Install Base from install-destination-softwares[0m
		call C:\Admin\Scripts\install-destination-softwares.bat base
		echo [36m Install Support from install-destination-softwares[0m
		call C:\Admin\Scripts\install-destination-softwares.bat support 

		echo [36m Create a cleanmgr preset :1[0m
		cleanmgr /sageset:1
	)

	if /I "%%a"=="systailoring" (
		echo [36mSet specific system parameters[0m 
		echo [36mDisable Widgets in menu bar for all users[0m 
		call C:\Admin\Scripts\set-registry.bat news-and-interests disable
		echo [36mReset Power Settings to an always-on status[0m 
		call C:\Admin\Scripts\reset-power-settings.bat
	)

	if /I "%%a"=="win-updates" (
		echo [36mInstall Power Shell Windows Updates Tools[0m 
		powershell -command "Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force"
		powershell -command "Install-Module PSWindowsUpdate -Force"
		powershell -command "Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted"
	)

	if /I "%%a"=="deploy-azure" (
		echo [36mConfigure System for Azure joining[0m 
		echo [36m Show AAD Users on Login Screen[0m
		call C:\Admin\Scripts\set-registry.bat aad-users show
		echo [36m Hide itadmin from Login Screen[0m
		call C:\Admin\Scripts\set-registry.bat local-user hide itadmin
	)
)

echo [92mDONE     [96m : CopyCat Prepare[0m
exit /b 0
