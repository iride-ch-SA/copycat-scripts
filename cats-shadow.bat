@echo off

rem ============================================================
rem  cats-shadow
rem  Copies the installation into a folder of its own under
rem  %TEMP% and points CATS_HOME at the copy, so that a run of
rem  cats reads its .bat files from somewhere git will not
rem  rewrite while they are being read.
rem
rem  Why. cmd.exe does not read a .bat into memory: it keeps a
rem  byte offset into the file and reopens it after every command
rem  to read the next line. cats update Scripts pulls over the
rem  very files that are being read that way, and from the pull
rem  on the old offset lands in the middle of the new content. On
rem  2026-09-21 that ran half a rem as a command, took a Windows
rem  Update block out of the if that guards it and then ran the
rem  whole dispatcher a second time. A chain that holds
rem  cats-resume.bat open can restart the machine the same way.
rem
rem  Two variables come out of here, and both are needed:
rem    CATS_HOME  the copy this run reads its .bat files from
rem    CATS_ROOT  the installation, C:\Admin\Scripts: what git
rem               pulls into, what goes on the system PATH, where
rem               the .ps1 helpers and the config files live, and
rem               what a scheduled task must point at - a task
rem               pointing into %TEMP% would find nothing there
rem               after the restart it was registered for
rem
rem  Called by the entry points only - cats.bat, cats-resume.bat
rem  and do-updates.bat - and only when CATS_HOME is not set yet:
rem  everything they call inherits it from the environment.
rem
rem  Exit codes: 0 the copy is there and CATS_HOME points at it;
rem  1 the copy could not be made, and CATS_HOME is left pointing
rem  at the installation itself - which is what cats did before
rem  this file existed, so the run works, but cats update Scripts
rem  is not safe in it.
rem ============================================================

if defined CATS_HOME exit /b 0

if not defined CATS_ROOT set "CATS_ROOT=%~dp0"
if "%CATS_ROOT:~-1%"=="\" set "CATS_ROOT=%CATS_ROOT:~0,-1%"

rem  The copies left by runs that are over. A .bat being read
rem  cannot be deleted, so nothing here can take a live run away,
rem  and a day is far longer than a cats run: a chain that spans
rem  restarts makes a new copy after each one of them
forfiles /p "%TEMP%" /m "cats-run-*" /d -1 /c "cmd /c if @isdir==TRUE rmdir /s /q @path" >nul 2>&1

set "CATS_SHADOW=%TEMP%\cats-run-%RANDOM%%RANDOM%"
if exist "%CATS_SHADOW%" set "CATS_SHADOW=%CATS_SHADOW%-%RANDOM%"

rem  .git is left behind: the copy is never pulled into, and it is
rem  the bulk of the tree
robocopy "%CATS_ROOT%" "%CATS_SHADOW%" /e /xd .git /njh /njs /ndl /nfl /nc /ns /np >nul 2>&1
if errorlevel 8 goto :failed
if not exist "%CATS_SHADOW%\cats.bat" goto :failed

set "CATS_HOME=%CATS_SHADOW%"
set "CATS_SHADOW="
exit /b 0

:failed
echo [33mWARNING   : the copy under %TEMP% could not be made, this run reads %CATS_ROOT% directly [0m
echo [33mWARNING   : cats update Scripts rewrites the files being read: do not run it in this run [0m
if exist "%CATS_SHADOW%" rmdir /s /q "%CATS_SHADOW%" >nul 2>&1
set "CATS_SHADOW="
set "CATS_HOME=%CATS_ROOT%"
exit /b 1
