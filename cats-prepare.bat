@echo off
setlocal enabledelayedexpansion

echo [95mSTARTING [96m : CopyCat Prepare[0m

for %%a in (%*) do (
	if exist C:\Admin\Scripts\cats-recipes\%%a.bat ( 
		call "C:\Admin\Scripts\cats-recipes\%%a.bat" prepare
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
