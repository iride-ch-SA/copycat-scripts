@echo off

rem  CATS_ROOT is where cats is installed, see cats-shadow.bat
if not defined CATS_ROOT set "CATS_ROOT=C:\Admin\Scripts"

if /I "%~1"=="prepare" (
	if exist "%CATS_ROOT%" (
		call "%~f0" update
		echo [32mRECIPE    : Add %CATS_ROOT% to System PATH [0m
		powershell -noprofile -executionpolicy bypass -command %CATS_ROOT%\ps\add-system-path.ps1 "%CATS_ROOT%"
		exit /b 0
	)
)

if /I "%~1"=="update" (
	if /I "%~2"=="reset" (
		echo [32mRECIPE    : Reset CopyCat Scripts from GIT [0m
		rmdir /s %CATS_ROOT% /q
		git clone https://github.com/iride-ch-SA/copycat-scripts.git %CATS_ROOT%
	) else (
		echo [32mRECIPE    : Update CopyCat Scripts with GIT [0m
		git --git-dir="%CATS_ROOT%\.git" --work-tree="%CATS_ROOT%" pull
	)
	exit /b 0
)

exit /b 2
