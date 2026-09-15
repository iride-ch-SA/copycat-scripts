@echo off
setlocal

set userlogin_task=Run userlogin script
set userlogin_script=C:\Admin\Scripts\userlogin.bat
set userlogin_others=C:\Admin\Others

if /I "%~1"=="deploy" (
	call :deploy "%~2"
	if errorlevel 1 exit /b 2
	exit /b 0
)

if /I "%~1"=="prepare" (
	call :prepare "%~2"
	if errorlevel 1 exit /b 2
	exit /b 0
)

exit /b 2

rem ============================================================
rem  deploy registers the sign-in task, and that is all it does.
rem  The task runs C:\Admin\Scripts\userlogin.bat at every logon,
rem  for every user of the machine: that file ships with the
rem  repository, applies the background through set-background.bat
rem  and calls whatever it finds in C:\Admin\Others - the shared
rem  userlogin.bat, and the <name>.bat of the user signing in.
rem  Those files are written by prepare, never here: deploy is the
rem  hook, prepare is what the hook calls, and the two verbs are
rem  not interchangeable.
rem  Nothing is ever written under C:\Admin\Scripts. That folder
rem  is the clone of the repository, so a file laid there is a
rem  local change to a tracked file and the next cats update
rem  Scripts stops pulling. If the tracked userlogin.bat is
rem  missing, the clone is incomplete: the way back is to restore
rem  it, not to lay an inert copy of it over the clone.
rem  Deploying a machine that is already deployed is not an error
rem  and is not work: the task is read back before anything is
rem  written, and if it is already registered for the group and
rem  points at the same file it is reported and left alone. One
rem  that exists and does not match - the single user task a
rem  fallback that failed halfway leaves behind - is named on the
rem  console and then rewritten.
rem ============================================================

:deploy
if not exist "%userlogin_script%" (
	echo [31mERROR     : %userlogin_script% is missing: it ships with the repository, so this clone is incomplete [0m
	echo [94mUSAGE     : restore it with cats update Scripts reset, then run cats deploy Userlogin again [0m
	exit /b 2
)

if not "%~1"=="" (
	echo [33mWARNING   : deploy takes no user name, so %~1 was ignored and no file was written [0m
	echo [94mUSAGE     : the sign-in scripts live in C:\Admin\Others and are written by cats prepare Userlogin %~1 [0m
)

echo [32mRECIPE    : Registering "%userlogin_task%" for every user of this machine [0m
rem The helper answers 3 when the task is already there exactly as asked, and
rem that code only survives the call because of the exit $LASTEXITCODE tail:
rem powershell -command hands back 1 for any non zero code without it, so the
rem two outcomes would arrive as the same number. Tested from the highest
rem code down, the way if errorlevel works
powershell -noprofile -executionpolicy bypass -command "& C:\Admin\Scripts\ps\register-logon-task.ps1 -taskname '%userlogin_task%' -command '%userlogin_script%' -sid S-1-5-32-545; exit $LASTEXITCODE"
if errorlevel 3 (
	echo [33mWARNING   : "%userlogin_task%" was already registered for every user of this machine, and was left as it is [0m
	echo [94mUSAGE     : there is nothing to deploy twice. Delete it with schtasks /delete /tn "%userlogin_task%" /f to register it from scratch [0m
	exit /b 0
)
if errorlevel 1 (
	echo [31mERROR     : "%userlogin_task%" is not registered for the Users group. Run this from an elevated prompt [0m
	exit /b 2
)

exit /b 0

rem ============================================================
rem  prepare writes the files userlogin.bat calls at every sign
rem  in, and writes them empty: what goes inside is the job of
rem  whoever configures the machine. Without a user name it is
rem  the shared one, C:\Admin\Others\userlogin.bat, which runs
rem  for everybody; with one it is C:\Admin\Others\<name>.bat,
rem  which runs for that user alone.
rem  The name of that file is not the name that gets typed: it
rem  has to be the USERNAME of the user, because that is what
rem  userlogin.bat looks for, and a domain or a tenant account
rem  signs in under a name of its own - gianni@tenant.ch is
rem  gianni on the machine. ps\resolve-logon-name.ps1 does that
rem  conversion, and says where it read the answer.
rem  An existing file is never overwritten: it holds commands
rem  somebody put there.
rem ============================================================

:prepare
if not exist "%userlogin_others%" (
	echo [36mRECIPE    : Creating %userlogin_others% [0m
	mkdir "%userlogin_others%"
)

if "%~1"=="" (
	echo [36mRECIPE    : Preparing the sign-in script shared by every user of this machine [0m
	call :write "%userlogin_others%\userlogin.bat" "REM Configure here commands runned for each user at logon"
	if errorlevel 1 exit /b 2
	exit /b 0
)

rem The name travels in the environment: it is quoted once, by nobody,
rem and a quote or a space in it cannot reach the PowerShell parser.
rem A helper called with -command hands back 1 for any failure it meets,
rem whatever code it exited with, so the name itself is the outcome that
rem is tested - for /f keeps standard output and leaves standard error
rem on the console, where the operator reads what the helper measured
set "UL_ACCOUNT=%~1"
set "UL_NAME="
echo [36mRECIPE    : Looking for the name %UL_ACCOUNT% signs in under [0m
for /f "usebackq delims=" %%n in (`powershell -noprofile -executionpolicy bypass -command "& C:\Admin\Scripts\ps\resolve-logon-name.ps1 -username $env:UL_ACCOUNT; exit $LASTEXITCODE"`) do set "UL_NAME=%%n"

if not defined UL_NAME (
	echo [31mERROR     : no sign-in name could be worked out for %UL_ACCOUNT%, nothing was written [0m
	echo [94mUSAGE     : cats prepare Userlogin username, an Entra account as user@tenant, a domain one as DOMAIN\user [0m
	exit /b 2
)

echo [36mRECIPE    : Preparing the sign-in script of %UL_ACCOUNT%, who signs in as %UL_NAME% [0m
call :write "%userlogin_others%\%UL_NAME%.bat" "REM Configure here commands runned for %UL_NAME%"
if errorlevel 1 exit /b 2
exit /b 0

:write
if exist "%~1" (
	echo [33mWARNING   : %~1 already exists and was left as it is [0m
	exit /b 0
)

> "%~1" echo %~2

rem The file is read back: a redirection that could not write says so on
rem a line that scrolls past, and a sign-in script that is not there is
rem a sign-in script nobody misses until it is needed
if not exist "%~1" (
	echo [31mERROR     : %~1 could not be created. Run this from an elevated prompt [0m
	exit /b 2
)

echo [32mRECIPE    : %~1 is ready to be filled in [0m
exit /b 0
