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
"%CATS_HOME%\do-updates.bat" %*
exit /b %errorlevel%

:shadowed
rem  If cats-shadow.bat is not there at all, this run is the one cats
rem  did before it existed: it works, bar cats update Scripts
if not defined CATS_ROOT set "CATS_ROOT=C:\Admin\Scripts"
if not defined CATS_HOME set "CATS_HOME=%CATS_ROOT%"

SET "PARAM=%~1"

REM **** permit ps executions
powershell -Command "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force"

IF /I "%PARAM%"=="git-reset" ( 
	git --git-dir="%CATS_ROOT%\.git" --work-tree="%CATS_ROOT%" fetch --all
	git --git-dir="%CATS_ROOT%\.git" --work-tree="%CATS_ROOT%" reset --hard origin/main
)

REM **** Update Scripts Folder
git --git-dir="%CATS_ROOT%\.git" --work-tree="%CATS_ROOT%" pull

IF /I "%PARAM%"=="git-only" ( goto :EOF)
IF /I "%PARAM%"=="git-reset" ( goto :EOF )

REM **** Do WinGet updates
winget upgrade --all --accept-package-agreements --accept-source-agreements

REM **** Update Office 365
"C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe" /update user displaylevel=false forceappshutdown=true

REM **** Windows Updates
powershell -command "Import-Module PSWindowsUpdate; Get-WindowsUpdate -Install -AcceptAll -AutoReboot"
