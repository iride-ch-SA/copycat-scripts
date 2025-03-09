@echo off

if "%~1"=="prepare" (
	if exist "C:\Admin\Scripts" (
		call :update
		echo [32mRECIPE    : Add C:\Admin\Scripts to System PATH [0m
		setx PATH "%PATH%;C:\Admin\Scripts" /M
		exit /b 0
	)
)

if "%~1"=="update" (
	:update
		echo [32mRECIPE    : Update CopyCat Scripts with GIT [0m
		git --git-dir="C:\Admin\Scripts\.git" --work-tree="C:\Admin\Scripts" pull
	exit /b 0
)

exit /b 2