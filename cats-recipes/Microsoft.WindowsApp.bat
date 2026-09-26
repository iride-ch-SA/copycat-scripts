@echo off
setlocal

rem  CATS_ROOT is where cats is installed, CATS_HOME the copy this
rem  run reads its .bat files from, see cats-shadow.bat
if not defined CATS_ROOT set "CATS_ROOT=C:\Admin\Scripts"
if not defined CATS_HOME set "CATS_HOME=C:\Admin\Scripts"

set wa_userlogin=C:\Admin\Others\userlogin.bat
set wa_script=%CATS_ROOT%\ps\windowsapp.ps1

if /I "%~1"=="install" (
	call :install
	if errorlevel 1 exit /b 2
	exit /b 0
)

exit /b 2

rem ============================================================
rem  install puts Windows App, the Remote Desktop and Windows 365
rem  client, on the machine for every user, and does four things:
rem    1. the two dependencies of the package, VCLibs and the
rem       Windows App Runtime, each with a winget install of its
rem       own and without --scope. The runtime is an exe with no
rem       scope in its manifest: asked for machine scope, winget
rem       finds no installer it can use and stops everything,
rem       Windows App included. The exit code of these two is not
rem       read: a dependency already there is not a failure, and
rem       step 3 is what says whether the app is in place.
rem    2. Windows App with --scope machine and --skip-dependencies.
rem       It is an msix, so machine scope makes winget provision
rem       it, and every profile gets it, those created later too.
rem       winget is called here and not through
rem       cats-install-winget.bat, which goes on to an upgrade
rem       without the switches when the app is already there.
rem    3. ps\windowsapp.ps1 -Machine, which checks the package is
rem       provisioned - the exit code of winget is not trusted -
rem       and provisions it itself if winget did not, then pins
rem       the app to the taskbar of the profiles created from now
rem       on, through LayoutModification.xml in the Default profile.
rem    4. the line that runs ps\windowsapp.ps1 at every sign in,
rem       appended once to C:\Admin\Others\userlogin.bat: it
rem       registers the app for a profile that existed before the
rem       provisioning. It runs only if the task of cats deploy
rem       Userlogin is registered.
rem  It is an administrator's job and the recipe refuses to start
rem  from a prompt that is not elevated.
rem ============================================================

:install
net session >nul 2>&1
if errorlevel 1 (
	echo [31mERROR     : Windows App is installed for every user by an administrator. Run this from an elevated prompt [0m
	exit /b 2
)

if not exist "%wa_script%" (
	echo [31mERROR     : %wa_script% is missing: it ships with the repository, so this clone is incomplete [0m
	echo [94mUSAGE     : restore it with cats update Scripts reset, then run cats install WindowsApp again [0m
	exit /b 2
)

echo [36mWINGET    : Installing the dependencies of Windows App, VCLibs and the Windows App Runtime [0m
winget install --id Microsoft.VCLibs.Desktop.14 -e --source winget --accept-package-agreements --accept-source-agreements
winget install --id Microsoft.WindowsAppRuntime.2 -e --source winget --accept-package-agreements --accept-source-agreements

echo [36mWINGET    : Installing Microsoft.WindowsApp for every user [0m
winget install --id Microsoft.WindowsApp -e --source winget --scope machine --skip-dependencies --accept-package-agreements --accept-source-agreements

powershell -noprofile -executionpolicy bypass -file "%wa_script%" -Machine
if errorlevel 5 (
	echo [31mERROR     : Windows App is not provisioned, the reason is on the lines above [0m
	exit /b 2
)
if errorlevel 4 (
	echo [33mWARNING   : Windows App is provisioned, but it is not pinned to the taskbar of new profiles [0m
	goto :userlogin
)
if errorlevel 1 (
	echo [31mERROR     : Windows App is not provisioned, the reason is on the lines above [0m
	exit /b 2
)

:userlogin
if not exist "%wa_userlogin%" (
	call "%CATS_HOME%\cats-recipes\Userlogin.bat" prepare
)
if not exist "%wa_userlogin%" (
	echo [31mERROR     : %wa_userlogin% is missing and could not be created, the sign in line was not added [0m
	exit /b 2
)

findstr /i /l /c:"windowsapp.ps1" "%wa_userlogin%" >nul
if not errorlevel 1 (
	echo [33mWARNING   : %wa_userlogin% already runs windowsapp.ps1 and was left as it is [0m
	exit /b 0
)

rem The empty line first: a file last saved by notepad may not end with a
rem line break, and the command would be glued to its last line
>> "%wa_userlogin%" echo(
>> "%wa_userlogin%" echo powershell -noprofile -executionpolicy bypass -file "%wa_script%"

findstr /i /l /c:"windowsapp.ps1" "%wa_userlogin%" >nul
if errorlevel 1 (
	echo [31mERROR     : the line could not be added to %wa_userlogin% [0m
	exit /b 2
)

echo [32mRECIPE    : %wa_userlogin% registers Windows App for every user at sign in [0m
exit /b 0
