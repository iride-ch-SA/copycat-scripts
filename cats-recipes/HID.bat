@echo off
setlocal enabledelayedexpansion

if "%~1"=="create" (
	SET PARAM="%~2"
	
	echo [32mRECIPE    : Executing HID Generator [0m
	powershell -noprofile -executionpolicy bypass -command C:\Admin\Scripts\ps\hid-generator.ps1 "!PARAM!"
	
	echo [32mRECIPE    : Writing HID to C:\Admin\Others\HID.txt [0m
	
	if not exist "C:\Admin\Others" (
		mkdir "C:\Admin\Others"
	)
	
	echo !HID! > "C:\Admin\Others\HID.txt"

	exit /b 0
)

exit /b 2