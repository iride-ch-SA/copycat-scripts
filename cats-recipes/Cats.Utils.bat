@echo off

if "%~1"=="install" (
	echo [32mRECIPE    : Install Cats Utilities [0m
	if exist C:\Admin\Scripts\cats-recipes\BgInfo.bat ( 
		call C:\Admin\Scripts\cats-recipes\BgInfo.bat install
	)
	if exist C:\Admin\Scripts\cats-recipes\Acronis.Agent.bat ( 
		call C:\Admin\Scripts\cats-recipes\Acronis.Agent.bat install
	)
)

if "%~1"=="prepare" (
	echo [32mRECIPE    : Prepare Cats Utilities [0m
	
	echo [32mRECIPE    : Create a cleanmgr sageset:1, select from GUI the clean settings to be saved [0m
	cmd /c cleanmgr /sageset:1
	echo [33mRECIPE    : Press a key when done [0m
	pause
	
	echo [32mRECIPE    : Disable Widgets in menu bar for all users [0m
	call C:\Admin\Scripts\set-registry.bat news-and-interests disable
	
	echo [32mRECIPE    : Reset Power Settings to an always-on status [0m
	call C:\Admin\Scripts\reset-power-settings.bat
)

exit /b 0