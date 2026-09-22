@echo off

rem  CATS_HOME is the copy this run reads its .bat files from, see cats-shadow.bat
if not defined CATS_HOME set "CATS_HOME=C:\Admin\Scripts"

if /I "%~1"=="install" (
	if "%PROCESSOR_ARCHITECTURE%" == "AMD64" (
		call "%CATS_HOME%\cats-install-winget.bat" Adobe.Acrobat.Reader.64-bit
		exit /b 0
	) else (
		call "%CATS_HOME%\cats-install-winget.bat" Adobe.Acrobat.Reader.32-bit
		exit /b 0
	)
)
exit /b 2