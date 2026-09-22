@echo off

rem  CATS_HOME is the copy this run reads its .bat files from, see cats-shadow.bat
if not defined CATS_HOME set "CATS_HOME=C:\Admin\Scripts"

if /I "%~1"=="install" (
	echo [32mRECIPE    : Install Cats Utilities [0m
	if exist "%CATS_HOME%\cats-recipes\BgInfo.bat" ( 
		call "%CATS_HOME%\cats-recipes\BgInfo.bat" install
	)
	rem  Acronis.Agent is not part of the utilities installed here. Its recipe stays
	rem  in place for the machines that want it, and cats install Acronis.Agent
	rem  installs it on demand.
	rem  Autologon belongs in the image rather than in the deployment that uses it: the first restart cats clean Wildcat asks for can
	rem  happen before that machine has a network, and a tool to be downloaded then
	rem  is a tool that is not there. No set-permissions for it, unlike BgInfo:
	rem  BgInfo runs at the logon of every user, Autologon is for an administrator.
	call "%CATS_HOME%\cats-install-winget.bat" Microsoft.Sysinternals.Autologon --location C:\Admin\Apps\ 
)

if /I "%~1"=="prepare" (
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