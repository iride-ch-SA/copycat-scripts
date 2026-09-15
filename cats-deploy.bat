@echo off
setlocal enabledelayedexpansion

echo [95mSTARTING [96m : CopyCat Deploy[0m

rem A recipe takes its own arguments, and the loop walks over those too:
rem cats deploy Userlogin mario passes mario to the recipe and then looks
rem for a recipe called mario. Only a parameter met before any recipe has
rem matched is a name of this verb, and only that one is worth a warning
set deploy_matched=0

for %%a in (%*) do (
	if exist C:\Admin\Scripts\cats-recipes\%%a.bat ( 
		set deploy_matched=1
		call "C:\Admin\Scripts\cats-recipes\%%a.bat" deploy %2 %3 %4 %5 %6 %7 %8 %9
	) else (
		if exist C:\Admin\Scripts\cats-recipes\Cats.%%a.bat (
			set deploy_matched=1
			call "C:\Admin\Scripts\cats-recipes\Cats.%%a.bat" deploy %2 %3 %4 %5 %6 %7 %8 %9
		) else (
			if "!deploy_matched!"=="0" echo [33mWARNING   : %%a is not a copycat recipe, there is nothing to deploy [0m
		)
	)
)

echo [92mDONE     [96m : CopyCat Deploy[0m
exit /b 0
