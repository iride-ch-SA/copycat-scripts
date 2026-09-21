@echo off

rem  CATS_HOME is the copy this run reads its .bat files from, see cats-shadow.bat
if not defined CATS_HOME set "CATS_HOME=C:\Admin\Scripts"

if "%~1"=="install" (
	call "%CATS_HOME%\cats-install-winget.bat" Microsoft.Sysinternals.BGInfo --location C:\Admin\Apps\ 
	call "%CATS_HOME%\set-permissions.bat" bginfo
	exit /b 0
)

exit /b 2