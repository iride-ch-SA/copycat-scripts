@echo off

set userlogin_task=Run userlogin script
set userlogin_script=C:\Admin\Scripts\userlogin.bat

if /I "%~1"=="deploy" (
	if not exist "%userlogin_script%" (
		echo [32mRECIPE    : Creating an empty %userlogin_script% [0m
		> "%userlogin_script%" echo REM Userlogin Script
	)

	echo [32mRECIPE    : Registering "%userlogin_task%" for every user of this machine [0m
	powershell -noprofile -executionpolicy bypass -command "C:\Admin\Scripts\ps\register-logon-task.ps1 -taskname '%userlogin_task%' -command '%userlogin_script%' -sid S-1-5-32-545"
	if errorlevel 1 (
		echo [31mERROR     : "%userlogin_task%" is not registered for the Users group. Run this from an elevated prompt [0m
		exit /b 2
	)

	exit /b 0
)

exit /b 2
