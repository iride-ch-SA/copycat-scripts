@echo off
setlocal enabledelayedexpansion

rem  CATS_HOME is the copy this run reads its .bat files from, see cats-shadow.bat
if not defined CATS_HOME set "CATS_HOME=C:\Admin\Scripts"

echo [95mSTARTING [96m : CopyCat Deploy[0m

rem A recipe can take its own arguments, and the loop walks over those
rem too: whatever follows the recipe name is passed to it and then looked
rem up as a recipe in its turn. Only a parameter met before any recipe has
rem matched is a name of this verb, and only that one is worth a warning
rem here - what comes after belongs to the recipe, which judges it itself
set deploy_matched=0

for %%a in (%*) do (
	if exist "%CATS_HOME%\cats-recipes\%%a.bat" ( 
		set deploy_matched=1
		call "%CATS_HOME%\cats-recipes\%%a.bat" deploy %2 %3 %4 %5 %6 %7 %8 %9
	) else (
		if exist "%CATS_HOME%\cats-recipes\Cats.%%a.bat" (
			set deploy_matched=1
			call "%CATS_HOME%\cats-recipes\Cats.%%a.bat" deploy %2 %3 %4 %5 %6 %7 %8 %9
		) else (
			if "!deploy_matched!"=="0" echo [33mWARNING   : %%a is not a copycat recipe, there is nothing to deploy [0m
		)
	)
)

echo [92mDONE     [96m : CopyCat Deploy[0m
exit /b 0
