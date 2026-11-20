@echo off
setlocal enabledelayedexpansion

rem Brother P-touch Editor 6, the label design software of the Brother label printers. Brother
rem ships it as an InstallShield self-extracting installer that carries the MSI, its own setup
rem and the Microsoft Access Database Engine.
rem
rem The recipe downloads the installer to C:\Admin\Installers, with the file name it has in the
rem bucket, and starts it only from an elevated prompt: the setup it unpacks is
rem requireAdministrator. Without elevation the download is the whole job, and the operator is
rem told how to go on.
rem
rem The installation is attended, the same arrangement chosen for Brother.LabelPrinter: the
rem operator answers Brother's setup on screen, and nothing is passed to the installer. Its exit
rem code is not trusted: on return the recipe looks for P-touch Editor among the installed
rem programs, in both registry views, since the MSI is 32-bit.
rem
rem   cats install Brother.PTouch
set PT_URL=https://storage.googleapis.com/01931185-232c-77a5-8e67-8751490ebf3e/CopyCats/Admin/Installers/Brother/pew6_13_0.exe
set PT_DIR=C:\Admin\Installers
set PT_EXE=%PT_DIR%\pew6_13_0.exe
set "PT_PART=%PT_EXE%.part"

if /I "%~1"=="install" (
	call :install
	if errorlevel 1 exit /b 2
	exit /b 0
)

exit /b 2

:install
if not exist "%PT_DIR%" ( mkdir "%PT_DIR%" )
if not exist "%PT_DIR%" (
	echo [31mERROR     : %PT_DIR% could not be created. Run this from an elevated prompt [0m
	exit /b 2
)

rem The download lands on a .part file and is renamed only once complete: a download broken
rem halfway would otherwise leave an installer that the next run takes as good
if not exist "%PT_EXE%" (
	echo [36mRECIPE    : Downloading the Brother P-touch Editor installer [0m
	powershell -noprofile -executionpolicy bypass -command "$ErrorActionPreference = 'Stop'; try { (New-Object System.Net.WebClient).DownloadFile($env:PT_URL, $env:PT_PART); Move-Item -LiteralPath $env:PT_PART -Destination $env:PT_EXE -Force } catch { Remove-Item -LiteralPath $env:PT_PART -Force -ErrorAction SilentlyContinue; [Console]::Error.WriteLine($_.Exception.Message); exit 1 }"
)

if not exist "%PT_EXE%" (
	echo [31mERROR     : the Brother P-touch Editor installer could not be downloaded [0m
	exit /b 2
)

net session >nul 2>&1
if errorlevel 1 (
	echo [33mWARNING   : this prompt is not elevated, the installer is downloaded but not started [0m
	echo [94mUSAGE     : run cats install Brother.PTouch again from an elevated prompt, or start %PT_EXE% as an administrator [0m
	exit /b 0
)

echo [36mRECIPE    : Starting the Brother P-touch Editor installer, follow the setup on screen [0m
"%PT_EXE%"
set ptExit=!ERRORLEVEL!

powershell -noprofile -executionpolicy bypass -command "$k = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'; $p = @(Get-ItemProperty -Path $k -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*P-touch Editor*' }); if ($p.Count -gt 0) { exit 0 } else { exit 1 }"
if errorlevel 1 (
	echo [31mERROR     : Brother P-touch Editor is not installed, the installer returned !ptExit! [0m
	echo [31mERROR     : if the Brother setup is still on screen, finish it and run this recipe again [0m
	exit /b 2
)

echo [36mRECIPE    : Brother P-touch Editor is installed [0m
exit /b 0
