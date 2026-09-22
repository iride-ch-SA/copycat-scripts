@echo off
setlocal enabledelayedexpansion

rem  CATS_HOME is the copy this run reads its .bat files from, see cats-shadow.bat
rem  CATS_ROOT is where cats is installed, see cats-shadow.bat
if not defined CATS_ROOT set "CATS_ROOT=C:\Admin\Scripts"
if not defined CATS_HOME set "CATS_HOME=%CATS_ROOT%"

set MC_CHAIN=clean disks+clean tmp+clean win-updates+clean sfc+clean dism-online

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

if /I "%~1"=="clean" (
	call :clean-machine "%~2"
	exit /b !errorlevel!
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

rem ============================================================
rem  clean runs the maintenance of the machine itself, in the
rem  order it was asked for:
rem    1. cats clean disks        cleanmgr with the sagerun:1 set
rem    2. cats clean tmp          the logs and the temporary files
rem    3. cats clean win-updates  the Windows Update folder
rem    4. cats clean sfc          sfc /scannow
rem    5. cats clean dism-online  the component store
rem
rem  The five are shortcuts of cats-clean.bat and every one of
rem  them can still be typed on its own: what this verb adds is
rem  the series. It is not run one step after the other inside
rem  this file, it is handed to cats-resume.bat as a chain -
rem  emptying the Windows Update folder needs a restart before
rem  the store is rebuilt, and a chain is what survives it.
rem  Whoever signs in as an administrator afterwards picks it up
rem  without typing anything.
rem
rem  Note on the order, which is the one that was asked for and
rem  is not the one Microsoft documents for a repair: DISM
rem  /RestoreHealth mends the component store sfc /scannow
rem  repairs from, so a machine where sfc reports corruption it
rem  could not correct wants the two run again the other way
rem  round, dism-online first.
rem
rem  Exit codes: 0 the chain was opened, 2 it was not - another
rem  chain is pending and was kept, or the marker could not be
rem  written. The exit code of the steps is theirs, and it is
rem  read on the console: a step that fails does not stop the
rem  ones after it.
rem ============================================================

:clean-machine
if not "%~1"=="" (
	echo [31mERROR     : Machine has no clean step called %~1 [0m
	echo [94mUSAGE     : cats clean Machine, or one step of it on its own: disks, tmp, win-updates, sfc, dism-online [0m
	exit /b 2
)

echo [36mRECIPE    : Cleaning this machine: %MC_CHAIN% [0m
echo [94mUSAGE     : it restarts on its own after the Windows Update folder. Sign in as an administrator afterwards and it carries on [0m
call "%CATS_HOME%\cats-resume.bat" open "clean Machine" "%MC_CHAIN%"
if errorlevel 2 (
	echo [31mERROR     : the chain was not started, the lines above say why [0m
	exit /b 2
)

echo [92mDONE     [96m : Machine[0m
exit /b 0
