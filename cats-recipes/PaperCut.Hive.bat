@echo off
setlocal

rem  CATS_ROOT is where cats is installed, CATS_HOME the copy this
rem  run reads its .bat files from, see cats-shadow.bat
if not defined CATS_ROOT set "CATS_ROOT=C:\Admin\Scripts"
if not defined CATS_HOME set "CATS_HOME=C:\Admin\Scripts"

set hive_others=C:\Admin\Others
set hive_config=C:\Admin\Others\papercut-hive.json
set hive_userlogin=C:\Admin\Others\userlogin.bat
set hive_script=%CATS_ROOT%\ps\papercut-hive.ps1

if /I "%~1"=="prepare" (
	call :prepare
	if errorlevel 1 exit /b 2
	exit /b 0
)

exit /b 2

rem ============================================================
rem  prepare readies a machine for the PaperCut Hive print client,
rem  which is installed and linked per user, at sign in, by
rem  ps\papercut-hive.ps1. It installs nothing, and does three
rem  things:
rem    1. C:\Admin\Others\papercut-hive.json, with the four keys
rem       of the customer left empty, to be filled in by hand.
rem       They are never in this repository, which is public.
rem       Until they are filled in the script stops at every
rem       sign in, says which ones are missing and exits 5.
rem    2. the line that runs the script, appended to the sign in
rem       script shared by every user, C:\Admin\Others\
rem       userlogin.bat. If that file is missing it is written
rem       first by cats prepare Userlogin, the recipe it belongs
rem       to. The line is added once: a file that already names
rem       papercut-hive.ps1 is left alone.
rem    3. the installer, C:\Admin\Installers\papercut-hive.exe,
rem       downloaded from the CopyCats bucket if it is missing, so
rem       that the first sign in does not wait for it. The download
rem       is done by the script itself, papercut-hive.ps1 -Fetch:
rem       the address and the way it is fetched live in one place,
rem       and the script still fetches it at sign in if it went
rem       missing afterwards.
rem  An existing JSON is never overwritten: it holds the keys.
rem  The sign in script runs only if the task of cats deploy
rem  Userlogin is registered, and the edge node, the per machine
rem  half of PaperCut Hive, is installed elevated elsewhere.
rem ============================================================

:prepare
if not exist "%hive_script%" (
	echo [31mERROR     : %hive_script% is missing: it ships with the repository, so this clone is incomplete [0m
	echo [94mUSAGE     : restore it with cats update Scripts reset, then run cats prepare PaperCut.Hive again [0m
	exit /b 2
)

if not exist "%hive_others%" (
	echo [36mRECIPE    : Creating %hive_others% [0m
	mkdir "%hive_others%"
)

call :config
if errorlevel 1 exit /b 2
call :userlogin
if errorlevel 1 exit /b 2
call :installer
if errorlevel 1 exit /b 2
exit /b 0

:installer
powershell -noprofile -executionpolicy bypass -file "%hive_script%" -Fetch
if errorlevel 1 (
	echo [31mERROR     : the PaperCut Hive installer is not in C:\Admin\Installers and could not be downloaded [0m
	echo [94mUSAGE     : the sign in script tries again at every sign in, or run cats prepare PaperCut.Hive again [0m
	exit /b 2
)
echo [32mRECIPE    : the PaperCut Hive installer is in C:\Admin\Installers [0m
exit /b 0

:config
if exist "%hive_config%" (
	echo [33mWARNING   : %hive_config% already exists and was left as it is [0m
	exit /b 0
)

> "%hive_config%" (
	echo {
	echo   "Region": "",
	echo   "OrgId": "",
	echo   "UserKey": "",
	echo   "SystemKey": ""
	echo }
)

rem The file is read back: a redirection that could not write says so on
rem a line that scrolls past
if not exist "%hive_config%" (
	echo [31mERROR     : %hive_config% could not be created. Run this from an elevated prompt [0m
	exit /b 2
)

echo [32mRECIPE    : %hive_config% is ready to be filled in with the keys of the customer [0m
echo [94mUSAGE     : Region, OrgId and UserKey come from the /CURRENTUSER command of the admin console, SystemKey from the edge node command [0m
exit /b 0

:userlogin
if not exist "%hive_userlogin%" (
	call "%CATS_HOME%\cats-recipes\Userlogin.bat" prepare
)
if not exist "%hive_userlogin%" (
	echo [31mERROR     : %hive_userlogin% is missing and could not be created, the line was not added [0m
	exit /b 2
)

findstr /i /l /c:"papercut-hive.ps1" "%hive_userlogin%" >nul
if not errorlevel 1 (
	echo [33mWARNING   : %hive_userlogin% already runs papercut-hive.ps1 and was left as it is [0m
	exit /b 0
)

rem The empty line first: a file last saved by notepad may not end with a
rem line break, and the command would be glued to its last line
>> "%hive_userlogin%" echo(
>> "%hive_userlogin%" echo powershell -noprofile -executionpolicy bypass -file "%hive_script%"

findstr /i /l /c:"papercut-hive.ps1" "%hive_userlogin%" >nul
if errorlevel 1 (
	echo [31mERROR     : the line could not be added to %hive_userlogin%. Run this from an elevated prompt [0m
	exit /b 2
)

echo [32mRECIPE    : %hive_userlogin% runs papercut-hive.ps1 at every sign in [0m
exit /b 0
