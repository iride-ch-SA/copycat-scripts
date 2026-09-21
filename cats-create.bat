@echo off
setlocal enabledelayedexpansion

rem  CATS_HOME is the copy this run reads its .bat files from, see cats-shadow.bat
if not defined CATS_HOME set "CATS_HOME=C:\Admin\Scripts"

echo [95mSTARTING [96m : CopyCat Create[0m

for %%a in (%*) do (
	if exist "%CATS_HOME%\cats-recipes\%%a.bat" ( 
		call "%CATS_HOME%\cats-recipes\%%a.bat" create %2 %3 %4 %5 %6 %7 %8 %9
	) else (
		if exist "%CATS_HOME%\cats-recipes\Cats.%%a.bat" (
			call "%CATS_HOME%\cats-recipes\Cats.%%a.bat" create %2 %3 %4 %5 %6 %7 %8 %9
		)
	)
	
	if /I "%%a"=="Admin" (
		if exist "%CATS_HOME%\cats-recipes\User.bat" (
			call "%CATS_HOME%\cats-recipes\User.bat" create %2 %3 Administrators %4 %5 %6 %7 %8
		)
	)
)

echo [92mDONE     [96m : CopyCat Create[0m
exit /b 0
