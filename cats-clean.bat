@echo off
setlocal enabledelayedexpansion

echo [95mSTARTING [96m : CopyCat Clean[0m

for %%a in (%*) do (
	if exist C:\Admin\Scripts\cats-recipes\%%a.bat ( 
		call "C:\Admin\Scripts\cats-recipes\%%a.bat" clean %2 %3 %4 %5 %6 %7 %8 %9
	) else (
		if exist C:\Admin\Scripts\cats-recipes\Cats.%%a.bat (
			call "C:\Admin\Scripts\cats-recipes\Cats.%%a.bat" clean %2 %3 %4 %5 %6 %7 %8 %9
		)
	)
	
	if /I "%%a"=="disks" (
		echo [36mSHORTCUT  : Do a Cleanmgr with sagerun:1 [0m
		cmd /c cleanmgr /sagerun:1
	)
	
	if /I "%%a"=="sfc" (
		echo [36mSHORTCUT  : Do an sfc /scannow [0m
		sfc /scannow
	)
	
	if /I "%%a"=="dism-online" (
		echo [36mSHORTCUT  : Restore Windows Image [0m
		DISM /Online /Cleanup-Image /AnalyzeComponentStore
		DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase
		DISM /Online /Cleanup-Image /RestoreHealth
	)
	
	if /I "%%a"=="network" (
		echo [36mSHORTCUT  : Fully reset Network [0m
		ipconfig /release & ipconfig /renew
		ipconfig /flushdns
		timeout /t 5 /nobreak >nul
		powershell -noprofile -executionpolicy bypass -command "Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private"
	)
	
	if /I "%%a"=="win-updates" (
		echo [36mSHORTCUT  : Clean Windows Updates folder [0m
		REM **** Clean Windows updates
		net stop wuauserv
		net stop bits
		del /f /s /q %windir%\SoftwareDistribution\*
		net start wuauserv
		net start bits
		echo Restart is required by the script, presse enter to restart.
		pause
		shutdown /r /t 0 
	)
	
	if /I "%%a"=="itadmin" (
		if /I not "%~1"=="User" (
			echo [36mSHORTCUT  : New random password for the itadmin account [0m
			if exist C:\Admin\Scripts\cats-recipes\User.bat (
				call "C:\Admin\Scripts\cats-recipes\User.bat" clean itadmin "%~2"
			)
		)
	)
	
	if /I "%%a"=="wildcat-deploy" (
		echo [36mSHORTCUT  : Remove VM drivers [0m
		winget uninstall RedHat.VirtIO --accept-source-agreements
	)
)

echo [92mDONE     [96m : CopyCat Clean[0m
exit /b 0
