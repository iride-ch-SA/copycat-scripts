@echo off
setlocal enabledelayedexpansion

rem  CATS_ROOT is where cats is installed, see cats-shadow.bat
if not defined CATS_ROOT set "CATS_ROOT=C:\Admin\Scripts"

if /I "%~1"=="create" (
	
	echo [32mRECIPE    : Executing HID Generator [0m
	if "%~2"=="" (
		powershell -noprofile -executionpolicy bypass -command %CATS_ROOT%\ps\hid-generator.ps1
	) else (
		SET PARAM="%~2"
		powershell -noprofile -executionpolicy bypass -command %CATS_ROOT%\ps\hid-generator.ps1 "!PARAM!"
	)
	
	echo [32mRECIPE    : Writing HID to C:\Admin\Others\HID.txt [0m
	for /f "delims=" %%i in ('powershell -noprofile -executionpolicy bypass -command "%CATS_ROOT%\ps\hid-generator.ps1"') do set HID=%%i
	
	if not exist "C:\Admin\Others" (
		mkdir "C:\Admin\Others"
	)
	
	echo !HID! > "C:\Admin\Others\HID.txt"

	exit /b 0
)

if /I "%~1"=="prepare" (
	call :rename-machine
	exit /b
)

exit /b 2

rem ============================================================
rem  prepare gives the machine a random name, PC- followed by 9
rem  characters drawn from A-Z0-9, and reboots it at once: that
rem  is what Rename-Computer -Restart does, and it is what the
rem  rename-pc.bat script in the root used to do before this
rem  recipe took it over.
rem  THE REBOOT IS IMMEDIATE AND UNCONFIRMED. cats-prepare.bat
rem  iterates over every parameter it is given, so anything
rem  typed after Machine on the same line does not run.
rem  The name travels in the environment rather than inside the
rem  quotes of -command, the same way the account name does in
rem  User.bat. Rename-Computer fails without an elevated prompt,
rem  and on a name already taken on the domain: it used to fail
rem  silently, with the recipe reporting nothing, so the error
rem  is now raised and the exit code carries it.
rem ============================================================

:rename-machine
set "chars=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
set "randomName="
for /l %%i in (1,1,9) do (
	set /a "randIndex=!random! %% 36"
	for %%j in (!randIndex!) do set "randomName=!randomName!!chars:~%%j,1!"
)

set "CATS_NEWNAME=PC-!randomName!"
echo [36mRECIPE    : Renaming this machine to !CATS_NEWNAME! - it reboots as soon as the name is written [0m
powershell -noprofile -executionpolicy bypass -command "try { Rename-Computer -NewName $env:CATS_NEWNAME -Restart -ErrorAction Stop } catch { Write-Error $_; exit 1 }"
if errorlevel 1 (
	echo [31mERROR     : the machine was not renamed, and it is not rebooting [0m
	exit /b 1
)

exit /b 0
