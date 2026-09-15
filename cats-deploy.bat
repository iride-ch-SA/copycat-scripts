@echo off
setlocal enabledelayedexpansion

echo [95mSTARTING [96m : CopyCat Deploy[0m

for %%a in (%*) do (
	if exist C:\Admin\Scripts\cats-recipes\%%a.bat ( 
		call "C:\Admin\Scripts\cats-recipes\%%a.bat" deploy %2 %3 %4 %5 %6 %7 %8 %9
	) else (
		if exist C:\Admin\Scripts\cats-recipes\Cats.%%a.bat (
			call "C:\Admin\Scripts\cats-recipes\Cats.%%a.bat" deploy %2 %3 %4 %5 %6 %7 %8 %9
		) else (
			echo [33mWARNING   : %%a is not a copycat recipe, there is nothing to deploy [0m
		)
	)
)

echo [92mDONE     [96m : CopyCat Deploy[0m
exit /b 0
