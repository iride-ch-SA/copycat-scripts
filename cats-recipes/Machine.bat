@echo off
setlocal enabledelayedexpansion

rem  CATS_HOME is the copy this run reads its .bat files from, see cats-shadow.bat
rem  CATS_ROOT is where cats is installed, see cats-shadow.bat
if not defined CATS_ROOT set "CATS_ROOT=C:\Admin\Scripts"
if not defined CATS_HOME set "CATS_HOME=%CATS_ROOT%"

set MC_CHAIN=clean disks+clean tmp+clean win-updates+clean dism-online+clean sfc

if /I "%~1"=="create" (

	rem  The identifier is computed ONCE, and the same value is shown and written: the
	rem  helper is run a single time, so console and file cannot be two answers to the
	rem  same question.
	rem  THERE IS NO SALT. hid-generator.ps1 declares -Verbose and nothing else, and its
	rem  CmdletBinding attribute refuses anything else. A second word typed after Machine
	rem  is named on the console and ignored, never passed on.
	rem  Adding a salt is a change to the helper, not to this line.
	if not "%~2"=="" (
		echo [33mWARNING   : cats create Machine takes no second parameter, and %~2 is ignored [0m
		echo [94mUSAGE     : the identifier has no salt; run ps\hid-generator.ps1 -v to see what goes into it [0m
	)

	echo [32mRECIPE    : Executing HID Generator [0m
	set "HID="
	for /f "delims=" %%i in ('powershell -noprofile -executionpolicy bypass -command "& %CATS_ROOT%\ps\hid-generator.ps1"') do set "HID=%%i"
	if not defined HID (
		echo [31mERROR     : the hardware identifier could not be computed, the lines above say why [0m
		exit /b 2
	)
	echo [36mRECIPE    : HID !HID! [0m

	if not exist "C:\Admin\Others" (
		mkdir "C:\Admin\Others"
	)

	rem  Redirection first, and on purpose: with the redirection written after echo, the
	rem  space before it would be written to the file too, and a value ending in a digit
	rem  would turn that digit into a stream number
	> "C:\Admin\Others\HID.txt" echo !HID!
	echo [32mRECIPE    : Written to C:\Admin\Others\HID.txt [0m

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
rem  characters drawn from A-Z0-9. The name takes effect at the
rem  next restart, and the restart is ASKED FOR, not ordered:
rem  cats-resume.bat is told one is needed and the chain this
rem  step belongs to orders it, which is what keeps whatever
rem  follows on the command line, and the rest of the chain,
rem  alive. That is why this is a step cats clean Wildcat can
rem  carry.
rem  The name travels in the environment rather than inside the
rem  quotes of -command, the same way the account name does in
rem  User.bat. Rename-Computer fails without an elevated prompt,
rem  and on a name already taken on the domain: the error is
rem  raised and the exit code carries it.
rem ============================================================

:rename-machine
set "chars=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
set "randomName="
for /l %%i in (1,1,9) do (
	set /a "randIndex=!random! %% 36"
	for %%j in (!randIndex!) do set "randomName=!randomName!!chars:~%%j,1!"
)

set "CATS_NEWNAME=PC-!randomName!"
echo [36mRECIPE    : Renaming this machine to !CATS_NEWNAME! [0m

rem  The restart is NOT ordered here any more, and that is what lets this step
rem  be part of a chain. Rename-Computer -Restart reboots the machine on the
rem  spot: cats-prepare.bat would lose whatever was typed after Machine on the
rem  same line, and a chain would lose its own runner, because cats-resume
rem  registers the task that picks the chain up only when IT orders a restart.
rem  So the name is written and a restart is asked for, the way every other
rem  step of this repository asks - see cats-recipes\Drivers.bat and
rem  cats clean win-updates. Typed by hand, outside a chain,
rem  nothing restarts: the name is pending and the console says so.
powershell -noprofile -executionpolicy bypass -command "try { Rename-Computer -NewName $env:CATS_NEWNAME -ErrorAction Stop } catch { Write-Error $_; exit 1 }"
if errorlevel 1 (
	echo [31mERROR     : the machine was not renamed [0m
	exit /b 1
)

echo [33mWARNING   : the new name takes effect at the next restart [0m
call "%CATS_HOME%\cats-resume.bat" request
exit /b 0

rem ============================================================
rem  clean runs the maintenance of the machine itself, in this
rem  order:
rem    1. cats clean disks        cleanmgr with the sagerun:1 set
rem    2. cats clean tmp          the logs and the temporary files
rem    3. cats clean win-updates  the Windows Update folder
rem    4. cats clean dism-online  the component store
rem    5. cats clean sfc          sfc /scannow
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
rem  Note on the order of the last two, dism-online before sfc:
rem  DISM /RestoreHealth mends the component store sfc /scannow
rem  repairs from, so the store is sound before sfc reads it -
rem  which is the order Microsoft documents for a repair, and
rem  which keeps sfc from reporting corruption it cannot
rem  correct.
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
	echo [94mUSAGE     : cats clean Machine, or one step of it on its own: disks, tmp, win-updates, dism-online, sfc [0m
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
