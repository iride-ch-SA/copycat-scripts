@echo off
setlocal enabledelayedexpansion

echo [95mSTARTING [96m : CopyCat Update[0m

for %%a in (%*) do (
	if exist C:\Admin\Scripts\cats-recipes\%%a.bat ( 
		call "C:\Admin\Scripts\cats-recipes\%%a.bat" update
	) 
)

echo [92mDONE     [96m : CopyCat Update[0m
exit /b 0
