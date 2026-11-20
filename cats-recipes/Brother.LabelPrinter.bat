@echo off
setlocal enabledelayedexpansion

rem Brother label printers of the QL-8xx series: QL-800, QL-810W and QL-820NWB share one
rem driver package, and Brother ships it as a single self-extracting installer.
rem
rem The recipe downloads the installer to C:\Admin\Drivers\Brother, with the file name it has
rem in the bucket, and starts it only from an elevated prompt: the installer is
rem requireAdministrator, and from a prompt that is not elevated cmd cannot start it at all.
rem Without elevation the download is the whole job, and the operator is told how to go on.
rem
rem The installation is attended, the same arrangement chosen for HPSA9: Brother's wizard
rem asks for the licence and for the printer model, and the operator answers it on screen.
rem Nothing is passed to the installer. Its exit code is not trusted: on return the recipe
rem looks for the driver itself, as a printer driver known to the spooler or as the
rem bsq16av.inf package in the driver store.
rem
rem   cats install Brother.LabelPrinter
set BR_URL=https://storage.googleapis.com/01931185-232c-77a5-8e67-8751490ebf3e/CopyCats/Admin/Drivers/Brother/QL-8xx/bsq16aw1101cus.exe
set BR_DIR=C:\Admin\Drivers\Brother
set BR_EXE=%BR_DIR%\bsq16aw1101cus.exe
set "BR_PART=%BR_EXE%.part"

if /I "%~1"=="install" (
	call :install
	if errorlevel 1 exit /b 2
	exit /b 0
)

exit /b 2

:install
if not exist "%BR_DIR%" ( mkdir "%BR_DIR%" )
if not exist "%BR_DIR%" (
	echo [31mERROR     : %BR_DIR% could not be created. Run this from an elevated prompt [0m
	exit /b 2
)

rem The download lands on a .part file and is renamed only once complete: a download broken
rem halfway would otherwise leave an installer that the next run takes as good
if not exist "%BR_EXE%" (
	echo [36mRECIPE    : Downloading the Brother QL-8xx driver installer [0m
	powershell -noprofile -executionpolicy bypass -command "$ErrorActionPreference = 'Stop'; try { (New-Object System.Net.WebClient).DownloadFile($env:BR_URL, $env:BR_PART); Move-Item -LiteralPath $env:BR_PART -Destination $env:BR_EXE -Force } catch { Remove-Item -LiteralPath $env:BR_PART -Force -ErrorAction SilentlyContinue; [Console]::Error.WriteLine($_.Exception.Message); exit 1 }"
)

if not exist "%BR_EXE%" (
	echo [31mERROR     : the Brother QL-8xx driver installer could not be downloaded [0m
	exit /b 2
)

net session >nul 2>&1
if errorlevel 1 (
	echo [33mWARNING   : this prompt is not elevated, the installer is downloaded but not started [0m
	echo [94mUSAGE     : run cats install Brother.LabelPrinter again from an elevated prompt, or start %BR_EXE% as an administrator [0m
	exit /b 0
)

echo [36mRECIPE    : Starting the Brother QL-8xx driver installer, follow the wizard on screen [0m
"%BR_EXE%"
set brExit=!ERRORLEVEL!

powershell -noprofile -executionpolicy bypass -command "$d = @(Get-PrinterDriver -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Brother QL-8*' }); $s = @(Get-WindowsDriver -Online -ErrorAction SilentlyContinue | Where-Object { $_.OriginalFileName -like '*\bsq16av.inf' }); if ($d.Count + $s.Count -gt 0) { exit 0 } else { exit 1 }"
if errorlevel 1 (
	echo [31mERROR     : the Brother QL-8xx driver is not installed, the installer returned !brExit! [0m
	echo [31mERROR     : if the Brother setup is still on screen, finish it and run this recipe again [0m
	exit /b 2
)

echo [36mRECIPE    : the Brother QL-8xx driver is installed [0m
exit /b 0
