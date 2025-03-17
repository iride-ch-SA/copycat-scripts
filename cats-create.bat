@echo off
setlocal enabledelayedexpansion

echo [95mSTARTING [96m : CopyCat Create[0m

for %%a in (%*) do (
	if exist C:\Admin\Scripts\cats-recipes\%%a.bat ( 
		call "C:\Admin\Scripts\cats-recipes\%%a.bat" create %2 %3 %4 %5 %6 %7 %8 %9
	) else (
		if exist C:\Admin\Scripts\cats-recipes\Cats.%%a.bat ((
			call "C:\Admin\Scripts\cats-recipes\Cats.%%a.bat" create %2 %3 %4 %5 %6 %7 %8 %9
		)
	)
	
	if /I "%%a"=="Admin" (
		if exist C:\Admin\Scripts\cats-recipes\User.bat (
			call "C:\Admin\Scripts\cats-recipes\User.bat" create %2 %3 Administrators
		)
	)
)

echo [92mDONE     [96m : CopyCat Create[0m
exit /b 0
