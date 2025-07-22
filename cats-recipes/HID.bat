@echo off
setlocal enabledelayedexpansion

if "%~1"=="create" (
	
	echo [32mRECIPE    : Executing HID Generator [0m
	if "%~2"=="" (
		powershell -noprofile -executionpolicy bypass -command C:\Admin\Scripts\ps\hid-generator.ps1
	) else (
		SET PARAM="%~2"
		powershell -noprofile -executionpolicy bypass -command C:\Admin\Scripts\ps\hid-generator.ps1 "!PARAM!"
	)
	
	echo [32mRECIPE    : Writing HID to C:\Admin\Others\HID.txt [0m
	for /f "delims=" %%i in ('powershell -noprofile -executionpolicy bypass -command "C:\Admin\Scripts\ps\hid-generator.ps1"') do set HID=%%i
	
	if not exist "C:\Admin\Others" (
		mkdir "C:\Admin\Others"
	)
	
	echo !HID! > "C:\Admin\Others\HID.txt"

	exit /b 0
)

exit /b 2