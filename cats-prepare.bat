@echo off
setlocal enabledelayedexpansion

rem  CATS_HOME is the copy this run reads its .bat files from, see cats-shadow.bat
if not defined CATS_HOME set "CATS_HOME=C:\Admin\Scripts"

echo [95mSTARTING [96m : CopyCat Prepare[0m

for %%a in (%*) do (
	if exist "%CATS_HOME%\cats-recipes\%%a.bat" ( 
		call "%CATS_HOME%\cats-recipes\%%a.bat" prepare %2 %3 %4 %5 %6 %7 %8 %9
	) else (
		if exist "%CATS_HOME%\cats-recipes\Cats.%%a.bat" (
			call "%CATS_HOME%\cats-recipes\Cats.%%a.bat" prepare %2 %3 %4 %5 %6 %7 %8 %9
		)
	)

	rem  The shortcuts of cats prepare Microsoft.Windows, which installs
	rem  what cats update Windows needs. win-updates is the old name
	set "PR_WINDOWS="
	if /I "%%a"=="Windows" set "PR_WINDOWS=1"
	if /I "%%a"=="win-updates" set "PR_WINDOWS=1"
	if defined PR_WINDOWS (
		echo [36mSHORTCUT  : Windows Update tools, see cats-recipes\Microsoft.Windows.bat [0m
		if exist "%CATS_HOME%\cats-recipes\Microsoft.Windows.bat" (
			call "%CATS_HOME%\cats-recipes\Microsoft.Windows.bat" prepare %2 %3 %4 %5 %6 %7 %8 %9
		)
	)
)

echo [92mDONE     [96m : CopyCat Prepare[0m
exit /b 0
