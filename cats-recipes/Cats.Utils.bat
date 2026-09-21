@echo off

rem  CATS_HOME is the copy this run reads its .bat files from, see cats-shadow.bat
if not defined CATS_HOME set "CATS_HOME=C:\Admin\Scripts"

if "%~1"=="install" (
	echo [32mRECIPE    : Install Cats Utilities [0m
	if exist "%CATS_HOME%\cats-recipes\BgInfo.bat" ( 
		call "%CATS_HOME%\cats-recipes\BgInfo.bat" install
	)
	if exist "%CATS_HOME%\cats-recipes\Acronis.Agent.bat" ( 
		call "%CATS_HOME%\cats-recipes\Acronis.Agent.bat" install
	)
)

if "%~1"=="prepare" (
	echo [32mRECIPE    : Prepare Cats Utilities [0m
	
	echo [32mRECIPE    : Create a cleanmgr sageset:1, select from GUI the clean settings to be saved [0m
	cmd /c cleanmgr /sageset:1
	echo [33mRECIPE    : Press a key when done [0m
	pause
	
	echo [32mRECIPE    : Disable Widgets in menu bar for all users [0m
	call "%CATS_HOME%\set-registry.bat" news-and-interests disable
	
	echo [32mRECIPE    : Reset Power Settings to an always-on status [0m
	call "%CATS_HOME%\reset-power-settings.bat"
)

exit /b 0