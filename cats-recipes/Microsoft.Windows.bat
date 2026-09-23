@echo off
setlocal

rem  CATS_ROOT is where cats is installed, see cats-shadow.bat
if not defined CATS_ROOT set "CATS_ROOT=C:\Admin\Scripts"

rem ============================================================
rem  Microsoft.Windows
rem  cats clean Microsoft.Windows takes the consumer apps off a
rem  Windows 11 workstation - Quick Assist, Microsoft Bing, News,
rem  Weather, Solitaire, Xbox and the like - for every user and
rem  in the provisioned copies that would hand them to the next
rem  user, and writes the settings a workplace wants: the Start
rem  menu in List view and without recommendations, no promoted
rem  apps installed behind the user's back, no Bing results in
rem  search, no tips and nags, no advertising ID, no game
rem  recording, diagnostic data at Required, fast startup off.
rem  The per-user ones go in every profile, the default one
rem  included.
rem  cats clean Microsoft.Windows list says what it would change
rem  and changes nothing.
rem  It refuses to run on a server and on anything older than
rem  Windows 11. The work is done by ps\clean-windows.ps1, which
rem  holds the list of the packages and of the settings.
rem  Exit codes: 0 something was changed, 1 there was nothing to
rem  change, 2 the machine is not a Windows 11 workstation or a
rem  change failed.
rem ============================================================

if /I "%~1"=="clean" (

	if /I "%~2"=="list" (
		echo [36mRECIPE    : What a clean of the Windows apps and settings would change [0m
		powershell -noprofile -executionpolicy bypass -command "& %CATS_ROOT%\ps\clean-windows.ps1 -List; exit $LASTEXITCODE"
	) else (
		echo [36mRECIPE    : Removing the consumer apps of Windows and writing the workplace settings [0m
		powershell -noprofile -executionpolicy bypass -command "& %CATS_ROOT%\ps\clean-windows.ps1; exit $LASTEXITCODE"
	)

	rem if errorlevel is greater-or-equal, so 2 is asked before 1
	if errorlevel 2 (
		echo [31mERROR     : the clean was refused or did not finish, the reason is in the lines above [0m
		exit /b 2
	)
	if errorlevel 1 (
		echo [33mWARNING   : there was nothing to change on this machine [0m
		exit /b 1
	)

	echo [36mRECIPE    : Windows cleaned [0m
	exit /b 0
)

exit /b 2
