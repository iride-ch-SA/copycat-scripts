@echo off
setlocal enabledelayedexpansion

rem  CATS_HOME is the copy this run reads its .bat files from, see cats-shadow.bat
if not defined CATS_HOME set "CATS_HOME=C:\Admin\Scripts"

echo [95mSTARTING [96m : CopyCat Remove[0m

rem  Only the User recipe answers to remove: cats remove User <name>
rem  [delete-profile|keep-profile], see cats-recipes\User.bat
for %%a in (%*) do (
	if exist "%CATS_HOME%\cats-recipes\%%a.bat" ( 
		call "%CATS_HOME%\cats-recipes\%%a.bat" remove %2 %3 %4 %5 %6 %7 %8 %9
	) else (
		if exist "%CATS_HOME%\cats-recipes\Cats.%%a.bat" (
			call "%CATS_HOME%\cats-recipes\Cats.%%a.bat" remove %2 %3 %4 %5 %6 %7 %8 %9
		)
	)
)

echo [92mDONE     [96m : CopyCat Remove[0m
exit /b 0
