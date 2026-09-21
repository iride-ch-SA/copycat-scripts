@echo off
setlocal

rem  CATS_ROOT is where cats is installed, see cats-shadow.bat
if not defined CATS_ROOT set "CATS_ROOT=C:\Admin\Scripts"

rem ============================================================
rem  Microsoft.Teams
rem  cats clean Microsoft.Teams takes every Teams off this
rem  machine: the MSTeams package for all users, the provisioned
rem  copy that would hand it to the next user who signs in, the
rem  consumer MicrosoftTeams package, and classic Teams - the
rem  machine-wide MSI, the per-user copy it leaves in each
rem  profile and the logon value that puts it back.
rem  The work is done by ps\remove-teams.ps1, which is where the
rem  registry and the profiles are read: a recipe that did it
rem  inline would spend its length on quoting.
rem  Exit codes: 0 something was removed, 1 there was no Teams to
rem  remove, 2 a removal failed.
rem ============================================================

if /I "%~1"=="clean" (

	echo [36mRECIPE    : Removing every Microsoft Teams installation from this machine [0m
	powershell -noprofile -executionpolicy bypass -command "& %CATS_ROOT%\ps\remove-teams.ps1; exit $LASTEXITCODE"

	rem if errorlevel is greater-or-equal, so 2 is asked before 1. The
	rem closing lines are painted by PowerShell rather than by an escape
	rem sequence: the Squirrel uninstaller of classic Teams is a graphical
	rem program and may hand the console back with virtual terminal mode off
	if errorlevel 2 (
		powershell -noprofile -command "Write-Host 'ERROR     : Teams was not fully removed, the reason is in the lines above' -ForegroundColor Red"
		exit /b 2
	)
	if errorlevel 1 (
		powershell -noprofile -command "Write-Host 'WARNING   : There was no Teams installation to remove' -ForegroundColor Yellow"
		exit /b 1
	)

	powershell -noprofile -command "Write-Host 'RECIPE    : Teams is gone from this machine' -ForegroundColor Cyan"
	exit /b 0
)

exit /b 2
