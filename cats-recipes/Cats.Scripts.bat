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

		rem  The clone comes first, and into a folder of its own. The run
		rem  reads out of the shadow copy and not out of CATS_ROOT, so the
		rem  rmdir below really does empty it. A clone that failed after such
		rem  an rmdir - no network, no git, no credentials - would leave the
		rem  machine with no cats at all: nothing on the system PATH and no
		rem  command for the resume task. So the tree in place goes only once
		rem  the new one is on disk and has a cats.bat in it.
		if exist "%CATS_ROOT%.new" rmdir /s /q "%CATS_ROOT%.new"
		git clone https://github.com/iride-ch-SA/copycat-scripts.git "%CATS_ROOT%.new"
		if not exist "%CATS_ROOT%.new\cats.bat" (
			echo [31mERROR     : the clone failed, %CATS_ROOT% is left as it was [0m
			if exist "%CATS_ROOT%.new" rmdir /s /q "%CATS_ROOT%.new"
			exit /b 2
		)
		if exist "%CATS_ROOT%" rmdir /s /q "%CATS_ROOT%"
		move "%CATS_ROOT%.new" "%CATS_ROOT%" >nul
	) else (
		echo [32mRECIPE    : Update CopyCat Scripts with GIT [0m
		git --git-dir="%CATS_ROOT%\.git" --work-tree="%CATS_ROOT%" pull
	)
	exit /b 0
)

exit /b 2
