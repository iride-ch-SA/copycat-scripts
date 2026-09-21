@echo off
setlocal enabledelayedexpansion

rem ============================================================
rem  cats resume
rem  A chain of cats steps that survives one or more restarts.
rem  A step that is done but needs a restart before the next one
rem  can run says so, and the chain picks itself up after the
rem  operator signs in again as an administrator.
rem
rem  Three pieces, and nothing else:
rem    1. the marker C:\Admin\Others\resume.state, plain
rem       key=value, holding what is left to run;
rem    2. a scheduled task that runs THIS file at every sign in
rem       of a member of Administrators, elevated;
rem    3. this runner, which walks the chain one step at a time.
rem
rem    cats resume              run what the marker still holds
rem    cats resume status       say what the marker holds
rem    cats resume cancel       drop the chain, marker and task
rem
rem  Called by the scripts themselves, never typed:
rem    cats-resume.bat open "<origin>" "<step+step+step>"
rem    cats-resume.bat request        this step needs a restart
rem    cats-resume.bat request again  and has to run once more
rem
rem  The steps are written the way they are typed after cats, and
rem  are separated by a plus sign: a pipe would be an operator of
rem  cmd on every line this file echoes it, a plus is nothing to
rem  anybody. "install Drivers+update Windows" is two steps.
rem
rem  A step asks for a restart by calling "request" - it is not
rem  guessed from an exit code. That keeps the convention of the
rem  recipes intact: a step that FAILS does not stop the ones
rem  after it, and only the distinct "a restart is needed" signal
rem  is acted upon. request writes C:\Admin\Others\resume.reboot,
rem  which this runner reads after every step and removes before
rem  the next one.
rem
rem  Exit codes: 0 the chain is finished or there was nothing to
rem  do, 2 the marker could not be written or the task could not
rem  be registered, 3 the chain was stopped at the cycle ceiling.
rem ============================================================

set RESUME_DIR=C:\Admin\Others
set RESUME_STATE=C:\Admin\Others\resume.state
set RESUME_FLAG=C:\Admin\Others\resume.reboot
set RESUME_TASK=Resume cats chain
set RESUME_SELF=C:\Admin\Scripts\cats-resume.bat
set RESUME_MAXCYCLE=8
set RESUME_WAIT=20

if /I "%~1"=="open" (
	call :open "%~2" "%~3"
	exit /b !errorlevel!
)

if /I "%~1"=="request" (
	call :request "%~2"
	exit /b !errorlevel!
)

if /I "%~1"=="cancel" (
	call :cancel
	exit /b !errorlevel!
)

if /I "%~1"=="status" (
	call :status
	exit /b !errorlevel!
)

rem No verb, or "run": this is what the scheduled task invokes
call :run
exit /b !errorlevel!

rem ============================================================
rem  open starts a chain. The first step is not run here and
rem  there is no special case for it: the chain is written down
rem  whole and then walked, so a machine that dies between the
rem  two has the marker and not a step already lost.
rem  A marker of another origin is somebody else's chain half
rem  done - a cats install drivers typed by hand while a wildcat
rem  is in the middle of its own - and it is not written over
rem  without being shown and confirmed.
rem ============================================================

:open
if "%~1"=="" (
	echo [31mERROR     : cats-resume open needs an origin and a chain [0m
	exit /b 2
)
if "%~2"=="" (
	echo [31mERROR     : cats-resume open needs a chain of steps [0m
	exit /b 2
)

call :read
if defined RS_ORIGIN (
	if /I not "!RS_ORIGIN!"=="%~1" (
		echo [33mWARNING   : a chain opened by "cats !RS_ORIGIN!" is still pending on this machine [0m
		echo [94mUSAGE     : what is left of it: !RS_CHAIN! [0m
		set "RESUME_ANSWER="
		set /p RESUME_ANSWER=Type yes to drop it and start "%~1" instead, anything else to stop: 
		if /I not "!RESUME_ANSWER!"=="yes" (
			echo [36mRECIPE    : nothing was changed, the pending chain is still there [0m
			exit /b 2
		)
		call :clear
	)
)

set "RS_ORIGIN=%~1"
set "RS_CHAIN=%~2"
set RS_CYCLE=0
set "RS_STARTED="
for /f "usebackq delims=" %%t in (`powershell -noprofile -command "(Get-Date).ToString('s')"`) do set "RS_STARTED=%%t"

call :write
if errorlevel 1 exit /b 2

echo [36mRECIPE    : Chain "%~1" opened, %~2 [0m
call :run
exit /b !errorlevel!

rem ============================================================
rem  run walks the chain. One step is taken off the marker and
rem  the marker is written back BEFORE the step runs: a step that
rem  restarts the machine on its own, or a power cut in the
rem  middle of it, must not bring the whole chain back from the
rem  beginning.
rem  A step that asked for a restart with "request again" is put
rem  back at the head of the chain - that is how cats update
rem  Windows keeps going until it finds nothing left.
rem ============================================================

:run
call :read
if not defined RS_CHAIN (
	rem The task fires at every sign in, and most of them have no
	rem chain waiting: that is not an error, it is the normal day
	call :clear
	exit /b 0
)

echo [95mSTARTING [96m : CopyCat Resume, chain "!RS_ORIGIN!", cycle !RS_CYCLE![0m

:step
call :read
if not defined RS_CHAIN (
	echo [92mDONE     [96m : chain "!RS_ORIGIN!" is finished[0m
	call :clear
	exit /b 0
)

set "RS_STEP="
set "RS_REST="
for /f "tokens=1* delims=+" %%s in ("!RS_CHAIN!") do (
	set "RS_STEP=%%s"
	set "RS_REST=%%t"
)

if not defined RS_STEP (
	call :clear
	exit /b 0
)

rem Written back before the step runs, and the step it is about to
rem run is remembered in case it asks to be run again
set "RS_CURRENT=!RS_STEP!"
set "RS_CHAIN=!RS_REST!"
call :write
if errorlevel 1 exit /b 2

if exist "%RESUME_FLAG%" del /f /q "%RESUME_FLAG%" >nul 2>&1

echo [36mRESUME    : cats !RS_STEP! [0m
call C:\Admin\Scripts\cats.bat !RS_STEP!

if not exist "%RESUME_FLAG%" goto :step

rem The step asked for a restart. Whether it also asked to be run
rem again is in the flag file, written by request
set "RS_AGAIN="
for /f "usebackq delims=" %%f in ("%RESUME_FLAG%") do set "RS_AGAIN=%%f"
del /f /q "%RESUME_FLAG%" >nul 2>&1

call :read
if /I "!RS_AGAIN!"=="again" (
	if defined RS_CHAIN (
		set "RS_CHAIN=!RS_CURRENT!+!RS_CHAIN!"
	) else (
		set "RS_CHAIN=!RS_CURRENT!"
	)
)

set /a RS_CYCLE=!RS_CYCLE! + 1

if !RS_CYCLE! GTR %RESUME_MAXCYCLE% (
	echo [31mERROR     : %RESUME_MAXCYCLE% restarts were not enough for chain "!RS_ORIGIN!", it is stopped here [0m
	echo [94mUSAGE     : what is left: !RS_CHAIN!. Continue it with cats resume, or drop it with cats resume cancel [0m
	call :write
	call :unregister
	exit /b 3
)

call :write
if errorlevel 1 exit /b 2

call :register
if errorlevel 1 (
	echo [31mERROR     : the chain cannot pick itself up after the restart, so the machine is NOT restarted [0m
	echo [94mUSAGE     : restart it yourself, sign in as an administrator and run cats resume [0m
	exit /b 2
)

echo [33mWARNING   : a restart is needed to continue, and it starts in %RESUME_WAIT% seconds [0m
echo [94mUSAGE     : sign in as an administrator afterwards and the chain continues by itself [0m
echo [94mUSAGE     : still to do: !RS_CHAIN! [0m
shutdown /r /t %RESUME_WAIT% /c "CopyCat: the cats chain continues after you sign in"
exit /b 0

rem ============================================================
rem  request is the one line a step calls to say "I am done, but
rem  nothing after me can run until this machine restarts". With
rem  "again" the step is put back at the head of the chain and
rem  runs once more after the restart.
rem  It writes a file and returns. The restart is the runner's
rem  to order, not the step's: a step called by hand, outside a
rem  chain, leaves the flag behind and nothing restarts.
rem ============================================================

:request
if not exist "%RESUME_DIR%" mkdir "%RESUME_DIR%" >nul 2>&1
if /I "%~1"=="again" (
	> "%RESUME_FLAG%" echo again
) else (
	> "%RESUME_FLAG%" echo once
)
if not exist "%RESUME_FLAG%" (
	echo [31mERROR     : %RESUME_FLAG% could not be written, so the restart cannot be asked for [0m
	exit /b 2
)
echo [36mRECIPE    : a restart is needed before the rest of this chain can run [0m
exit /b 0

rem ============================================================
rem  status, cancel: what an operator has to say by hand
rem ============================================================

:status
call :read
if not defined RS_ORIGIN (
	echo [36mRECIPE    : no chain is pending on this machine [0m
	exit /b 0
)
echo [36mRECIPE    : chain "!RS_ORIGIN!" opened at !RS_STARTED!, !RS_CYCLE! restart(s) so far [0m
echo [36mRECIPE    : still to do: !RS_CHAIN! [0m
exit /b 0

:cancel
call :read
if not defined RS_ORIGIN (
	echo [36mRECIPE    : no chain was pending, the task was removed if it was there [0m
	call :clear
	exit /b 0
)
echo [33mWARNING   : chain "!RS_ORIGIN!" is dropped, !RS_CHAIN! was never run [0m
call :clear
exit /b 0

rem ============================================================
rem  The marker. Plain key=value so that a .bat reads it with a
rem  for /f and PowerShell with a ConvertFrom-StringData, and an
rem  operator with notepad. The keys are read into RS_<KEY> and
rem  not into <KEY>, because a marker holding PATH= would
rem  otherwise rewrite the path of this process.
rem ============================================================

:read
set "RS_ORIGIN="
set "RS_CHAIN="
set "RS_CYCLE=0"
set "RS_STARTED="
if not exist "%RESUME_STATE%" exit /b 0
for /f "usebackq eol=# tokens=1* delims==" %%a in ("%RESUME_STATE%") do (
	if not "%%b"=="" set "RS_%%a=%%b"
)
if not defined RS_CYCLE set "RS_CYCLE=0"
exit /b 0

:write
if not exist "%RESUME_DIR%" mkdir "%RESUME_DIR%" >nul 2>&1
> "%RESUME_STATE%" echo # CopyCat resume marker, written by cats-resume.bat. Drop it with cats resume cancel
>> "%RESUME_STATE%" echo ORIGIN=!RS_ORIGIN!
>> "%RESUME_STATE%" echo CHAIN=!RS_CHAIN!
>> "%RESUME_STATE%" echo CYCLE=!RS_CYCLE!
>> "%RESUME_STATE%" echo STARTED=!RS_STARTED!
if not exist "%RESUME_STATE%" (
	echo [31mERROR     : %RESUME_STATE% could not be written. Run this from an elevated prompt [0m
	exit /b 2
)
exit /b 0

:clear
if exist "%RESUME_STATE%" del /f /q "%RESUME_STATE%" >nul 2>&1
if exist "%RESUME_FLAG%" del /f /q "%RESUME_FLAG%" >nul 2>&1
call :unregister
exit /b 0

rem ============================================================
rem  The task. Registered only when a restart is actually about
rem  to happen, and removed as soon as the chain is over: a task
rem  left behind would try to resume a chain that is not there at
rem  every sign in of every administrator, forever.
rem  Administrators and not a single account, because whoever
rem  signs in after the restart is an administrator but not
rem  necessarily the same one. Elevated, because the steps it
rem  resumes install drivers and updates.
rem ============================================================

:register
if not exist "%RESUME_SELF%" (
	echo [31mERROR     : %RESUME_SELF% is missing: this clone is incomplete [0m
	exit /b 2
)
echo [36mRECIPE    : Registering "%RESUME_TASK%" so the chain continues after the restart [0m
powershell -noprofile -executionpolicy bypass -command "& C:\Admin\Scripts\ps\register-logon-task.ps1 -taskname '%RESUME_TASK%' -command '%RESUME_SELF%' -sid S-1-5-32-544 -elevated -timelimit PT4H -quiet; exit $LASTEXITCODE"
rem 3 is "already registered exactly as asked", which is what every
rem restart after the first one meets, and it is not a failure
if errorlevel 4 exit /b 2
if errorlevel 3 exit /b 0
if errorlevel 1 exit /b 2
exit /b 0

:unregister
schtasks /query /tn "%RESUME_TASK%" >nul 2>&1
if errorlevel 1 exit /b 0
schtasks /delete /tn "%RESUME_TASK%" /f >nul 2>&1
exit /b 0
