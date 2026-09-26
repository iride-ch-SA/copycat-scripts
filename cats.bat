@echo off

rem  This run reads its .bat files from a copy under %TEMP% and
rem  not from C:\Admin\Scripts, so that cats update Scripts can
rem  pull over the installation while the run is still going.
rem  cats-shadow.bat makes the copy and sets CATS_HOME and
rem  CATS_ROOT; the hand over below is a batch call WITHOUT
rem  "call", which ends this file instead of coming back to it -
rem  that is the whole point, cmd must be left with no offset
rem  into a file git is about to rewrite. See cats-shadow.bat
if defined CATS_HOME goto :shadowed
call "%~dp0cats-shadow.bat"
if errorlevel 1 goto :shadowed
"%CATS_HOME%\cats.bat" %*
exit /b %errorlevel%

:shadowed
rem  If cats-shadow.bat is not there at all, this run is the one cats
rem  did before it existed: it works, bar cats update Scripts
if not defined CATS_ROOT set "CATS_ROOT=C:\Admin\Scripts"
if not defined CATS_HOME set "CATS_HOME=%CATS_ROOT%"

echo [95mEXECUTING[96m : CopyCat Scripts[0m
:: Check if there is a verb
if "%~1"=="" (
	echo [31mERROR     : You must specify a verb as first parameter [0m
	echo [94mUSAGE     : cats install,uninstall,update,prepare,clean,set,create,deploy,backup,resume parameters [0m
	exit /b 2
) else (
	echo [36mCALLING   : cats %~1 %2 %3 %4 %5 %6 %7 %8 %9 [0m
)

:: Check if enough parameters are passed. resume is the one verb that
:: takes none: cats resume picks up the chain the marker already holds
if /I "%~1"=="resume" goto :verbs
if "%~2"=="" (
	echo [31mERROR     : You must specify at least one parameter for verb [91m%~1 [0m
	echo [94mUSAGE     : cats %~1 package-names, recipe or shortcut [0m
	exit /b 2
)

:verbs
:: How deep this run is: cats calls cats - a chain step, a recipe that
:: refreshes itself - and only the outermost run may offer to close the
:: window. Counted after the checks above, whose exits skip the count
set /a CATS_DEPTH+=1

:: Accept winget source agreements on the first run of this user
call "%CATS_HOME%\cats-winget-accept.bat"

:: Executing cats verbs and parameters
if /I "%~1"=="install" (
	call "%CATS_HOME%\cats-install.bat" %2 %3 %4 %5 %6 %7 %8 %9
)

if /I "%~1"=="uninstall" (
	echo [36mCALLING   : cats-uninstall %2 %3 %4 %5 %6 %7 %8 %9 [0m
)

if /I "%~1"=="update" (
	call "%CATS_HOME%\cats-update.bat" %2 %3 %4 %5 %6 %7 %8 %9
)

if /I "%~1"=="prepare" (
	call "%CATS_HOME%\cats-prepare.bat" %2 %3 %4 %5 %6 %7 %8 %9
)

if /I "%~1"=="clean" (
	call "%CATS_HOME%\cats-clean.bat" %2 %3 %4 %5 %6 %7 %8 %9
)

if /I "%~1"=="set" (
	echo [36mCALLING   : cats-set %2 %3 %4 %5 %6 %7 %8 %9 [0m
)

if /I "%~1"=="create" (
	call "%CATS_HOME%\cats-create.bat" %2 %3 %4 %5 %6 %7 %8 %9
)

if /I "%~1"=="deploy" (
	call "%CATS_HOME%\cats-deploy.bat" %2 %3 %4 %5 %6 %7 %8 %9
)

if /I "%~1"=="resume" (
	call "%CATS_HOME%\cats-resume.bat" %2 %3 %4 %5 %6 %7 %8 %9
)

if /I "%~1"=="backup" (
	echo [36mCALLING   : cats-backup %2 %3 %4 %5 %6 %7 %8 %9 [0m
	call "%CATS_HOME%\cats-backup.bat" %2 %3 %4 %5 %6 %7 %8 %9
)

set /a CATS_DEPTH-=1

echo [92mDONE     [96m : CopyCat Scripts[0m
if %CATS_DEPTH% GTR 0 exit /b 0
if defined CATS_SCRIPTS_PULLED call :stale
exit /b 0

:: cats update Scripts pulled while this run read its shadow copy, and
:: this window keeps pointing CATS_HOME at that copy: every cats typed
:: here from now on runs the code as it was before the pull. Closing is
:: the answer that needs nothing but Enter. Only a window someone types
:: into is asked: a cmd started with /c - the resume task, a cats run
:: from PowerShell - ends with the run and holds no copy afterwards
:stale
set "CATS_SCRIPTS_PULLED="
setlocal enabledelayedexpansion
set "STALE_CMD=!CMDCMDLINE!"
if /I not "!STALE_CMD:/c=!"=="!STALE_CMD!" (
	endlocal
	exit /b 0
)
echo.
echo [33mWARNING   : this window still runs the copy of cats taken before the update, not the updated one[0m
echo [33mWARNING   : any cats typed here would run the old code: close it and open a new window[0m
set "STALE_ANSWER="
set /p "STALE_ANSWER=Close this window now? [Y/n] "
if not defined STALE_ANSWER exit
if /I not "!STALE_ANSWER:~0,1!"=="n" exit
echo [33mWARNING   : window kept open, on the copy before the update[0m
endlocal
exit /b 0
