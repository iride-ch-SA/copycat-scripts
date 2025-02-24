@echo off
setlocal enabledelayedexpansion
set "do-restart=0"

for %%a in (%*) do (
	if /I "%%a"=="clean" (
		cleanmgr /sagerun:1
	)
		
	if /I "%%a"=="sfc" (
		sfc /scannow
	)

	if /I "%%a"=="dism-online" (
		DISM /Online /Cleanup-Image /AnalyzeComponentStore
		DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase
		DISM /Online /Cleanup-Image /RestoreHealth
	)
	
	if /I "%%a"=="network" (
		ipconfig /release & ipconfig /renew
		ipconfig /flushdns
		timeout /t 5 /nobreak >nul
		powershell -noprofile -executionpolicy bypass -command "Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private"
	)
	
	if /I "%%a"=="win-updates" (
		REM **** Clean Windows updates
		net stop wuauserv
		net stop bits
		del /f /s /q %windir%\SoftwareDistribution\*
		net start wuauserv
		net start bits
		set "dorestart=1"
	)
	
	if /I "%%a"=="wildcat-deploy" (
		winget uninstall "Acronis Snap Deploy 6 Management Agent"
		winget uninstall RedHat.VirtIO
		C:/Admin/Scripts/rename-pc.bat
	)
)

if "!dorestart!"=="1" ( 
	echo Restart is required by the script, presse enter to restart.
	pause
	shutdown /r /t 0 
)
