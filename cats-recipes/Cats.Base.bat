@echo off

rem  CATS_HOME is the copy this run reads its .bat files from, see cats-shadow.bat
if not defined CATS_HOME set "CATS_HOME=C:\Admin\Scripts"

if "%~1"=="install" (
	call "%CATS_HOME%\cats-install-winget.bat" Google.Chrome
	call "%CATS_HOME%\cats-install-winget.bat" Mozilla.Firefox
	call "%CATS_HOME%\cats-install-winget.bat" VideoLAN.VLC
	if exist "%CATS_HOME%\cats-recipes\Adobe.Acrobat.Reader.bat" ( 
		call "%CATS_HOME%\cats-recipes\Adobe.Acrobat.Reader.bat" install
	)
	exit /b 0
)

exit /b 2