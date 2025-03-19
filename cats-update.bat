@echo off
setlocal enabledelayedexpansion

echo [95mSTARTING [96m : CopyCat Update[0m

for %%a in (%*) do (
	if exist C:\Admin\Scripts\cats-recipes\%%a.bat ( 
		call "C:\Admin\Scripts\cats-recipes\%%a.bat" update %2 %3 %4 %5 %6 %7 %8 %9
	) else (
		if exist C:\Admin\Scripts\cats-recipes\Cats.%%a.bat (
			call "C:\Admin\Scripts\cats-recipes\Cats.%%a.bat" update %2 %3 %4 %5 %6 %7 %8 %9
		)
	)
	
	if /I "%%a"=="Windows" (
		winget upgrade --all --accept-package-agreements --accept-source-agreements
		powershell -Command "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force"
		powershell -command "Import-Module PSWindowsUpdate; Get-WindowsUpdate -Install -AcceptAll -AutoReboot"
	)
)

echo [92mDONE     [96m : CopyCat Update[0m
exit /b 0
