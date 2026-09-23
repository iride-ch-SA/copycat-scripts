@echo off
setlocal enabledelayedexpansion

rem  CATS_HOME is the copy this run reads its .bat files from, see cats-shadow.bat
rem  CATS_ROOT is where cats is installed, see cats-shadow.bat
if not defined CATS_ROOT set "CATS_ROOT=C:\Admin\Scripts"
if not defined CATS_HOME set "CATS_HOME=%CATS_ROOT%"

echo [95mSTARTING [96m : CopyCat Update[0m

for %%a in (%*) do (
	if exist "%CATS_HOME%\cats-recipes\%%a.bat" ( 
		call "%CATS_HOME%\cats-recipes\%%a.bat" update %2 %3 %4 %5 %6 %7 %8 %9
	) else (
		if exist "%CATS_HOME%\cats-recipes\Cats.%%a.bat" (
			call "%CATS_HOME%\cats-recipes\Cats.%%a.bat" update %2 %3 %4 %5 %6 %7 %8 %9
		)
	)
	
	rem  The shortcut of cats update Microsoft.Windows: the winget
	rem  upgrades and the pass of Windows Update live in that recipe
	if /I "%%a"=="Windows" (
		echo [36mSHORTCUT  : Windows updates, see cats-recipes\Microsoft.Windows.bat [0m
		if exist "%CATS_HOME%\cats-recipes\Microsoft.Windows.bat" (
			call "%CATS_HOME%\cats-recipes\Microsoft.Windows.bat" update %2 %3 %4 %5 %6 %7 %8 %9
		)
	)
)

echo [92mDONE     [96m : CopyCat Update[0m
exit /b 0
