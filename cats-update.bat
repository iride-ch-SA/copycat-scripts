@echo off
setlocal enabledelayedexpansion

echo [95mSTARTING [96m : CopyCat Update[0m

for %%a in (%*) do (
	if exist C:\Admin\Scripts\cats-recipes\%%a.bat ( 
		call "C:\Admin\Scripts\cats-recipes\%%a.bat" update %2 %3 %4 %5 %6 %7 %8 %9
	) else (
		if exist C:\Admin\Scripts\cats-recipes\Cats.%%a.bat (
			call "C:\Admin\Scripts\cats-recipes\Cats.%%a.bat" update %2 %3 %4 %5 %6 %7 %8 %9
		)
	)
)

echo [92mDONE     [96m : CopyCat Update[0m
exit /b 0
