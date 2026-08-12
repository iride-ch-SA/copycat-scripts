@echo off
setlocal enabledelayedexpansion

if "%~1"=="install" (
	if not exist "C:\Admin\Drivers\HP" ( mkdir C:\Admin\Drivers\HP )

	if not exist "C:\Admin\Drivers\HP\HPSA9.exe" (
		echo [36mRECIPE    : Downloading HP Support Assistant [0m
		powershell -command "(new-object System.Net.WebClient).DownloadFile('https://ftp.hp.com/pub/softpaq/sp163001-163500/sp163238.exe','C:\Admin\Drivers\HP\HPSA9.exe')"
	)

	if not exist "C:\Admin\Drivers\HP\HPSA9.exe" (
		echo [31mERROR     : HP Support Assistant installer could not be downloaded [0m
		exit /b 2
	)

	if not exist "C:\Admin\Drivers\HP\HPSA9\Setup.exe" (
		echo [36mRECIPE    : Extracting HP Support Assistant [0m
		"C:\Admin\Drivers\HP\HPSA9.exe" /s /e /f "C:\Admin\Drivers\HP\HPSA9"
	)

	if not exist "C:\Admin\Drivers\HP\HPSA9\Setup.exe" (
		echo [31mERROR     : Extraction failed, HP Support Assistant was not installed [0m
		exit /b 2
	)

	rem HPSA 9 needs the HP Fusion services: without them the setup stops with code -5
	sc query HPSysInfoCap >nul 2>&1
	if errorlevel 1 (
		echo [33mWARNING   : the HP Fusion service HPSysInfoCap is missing, the setup may refuse to install [0m
	)

	echo [36mRECIPE    : Starting the HP Support Assistant setup, follow the wizard on screen [0m
	"C:\Admin\Drivers\HP\HPSA9\Setup.exe"
	set hpsaExit=!ERRORLEVEL!

	powershell -noprofile -executionpolicy bypass -command "$p = @(Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like 'AD2F1837.HPSupportAssistant*' }); $u = @(Get-AppxPackage -AllUsers -Name 'AD2F1837.HPSupportAssistant'); if ($p.Count + $u.Count -gt 0) { exit 0 } else { exit 1 }"
	if errorlevel 1 (
		echo [31mERROR     : HP Support Assistant is not installed, Setup.exe returned !hpsaExit! [0m
		if "!hpsaExit!"=="-5" echo [31mERROR     : -5 means the HP Fusion services are missing or not running [0m
		if "!hpsaExit!"=="-6" echo [31mERROR     : -6 means an HPSA older than 8.8 is installed and cannot be upgraded [0m
		if "!hpsaExit!"=="-8" echo [31mERROR     : -8 means this Windows build or architecture is not supported [0m
		if "!hpsaExit!"=="-9" echo [31mERROR     : -9 means this Windows build or architecture is not supported [0m
		echo [31mERROR     : Setup.exe logs to system.sav\logs\HPSASetUpCpp.txt on the system drive [0m
		exit /b 2
	)

	echo [36mRECIPE    : HP Support Assistant is provisioned, it appears at next user logon [0m
	exit /b 0
)

exit /b 2
