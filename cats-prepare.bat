@echo off
setlocal enabledelayedexpansion

echo [95mSTARTING [96m : CopyCat Prepare[0m

for %%a in (%*) do (
	if exist C:\Admin\Scripts\cats-recipes\%%a.bat ( 
		call "C:\Admin\Scripts\cats-recipes\%%a.bat" prepare %2 %3 %4 %5 %6 %7 %8 %9
	) else (
		if exist C:\Admin\Scripts\cats-recipes\Cats.%%a.bat (
			call "C:\Admin\Scripts\cats-recipes\Cats.%%a.bat" prepare %2 %3 %4 %5 %6 %7 %8 %9
		)
	)

	if /I "%%a"=="win-updates" (
		echo [36mInstall Power Shell Windows Updates Tools[0m 
		powershell -command "Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force"
		powershell -command "Install-Module PSWindowsUpdate -Force"
		powershell -command "Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted"
	)
)

echo [92mDONE     [96m : CopyCat Prepare[0m
exit /b 0
