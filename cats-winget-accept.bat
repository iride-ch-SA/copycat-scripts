@echo off
setlocal

:: ============================================================
::  cats-winget-accept.bat
::  Accepts the winget source agreements once per user.
::  Without this, the first cats command that queries winget
::  stops on an interactive prompt asking to accept the msstore
::  terms, which blocks any unattended run.
::  winget records the acceptance in the user profile: the flag
::  file only avoids repeating the query on every cats command.
:: ============================================================

set "_catsdir=%LOCALAPPDATA%\Cats"
set "_flag=%_catsdir%\winget-accepted.flag"

if exist "%_flag%" exit /b 0

where winget >nul 2>&1
if errorlevel 1 (
	echo [33mWARNING   : winget not available for this user, source agreements not accepted [0m
	exit /b 1
)

echo [36mWINGET    : First cats run for %USERNAME%, accepting source agreements [0m
winget list --accept-source-agreements >nul 2>&1
if errorlevel 1 (
	echo [33mWARNING   : winget returned an error, source agreements may still be pending [0m
	exit /b 1
)

if not exist "%_catsdir%" mkdir "%_catsdir%" >nul 2>&1
> "%_flag%" echo Accepted by %USERNAME% on %DATE% %TIME%
exit /b 0
