@echo off

set userlogin_task=Run userlogin script
set userlogin_script=C:\Admin\Scripts\userlogin.bat

if /I "%~1"=="deploy" (
	if not exist "%userlogin_script%" (
		echo [32mRECIPE    : Creating an empty %userlogin_script% [0m
		> "%userlogin_script%" echo REM Userlogin Script
	)

	echo [32mRECIPE    : Registering "%userlogin_task%" for every user of this machine [0m
	powershell -noprofile -executionpolicy bypass -command "C:\Admin\Scripts\ps\register-logon-task.ps1 -taskname '%userlogin_task%' -command '%userlogin_script%' -sid S-1-5-32-545"
	if not errorlevel 1 exit /b 0

	echo [33mWARNING   : The task could not be registered for the Users group, falling back to schtasks [0m
	schtasks /create /tn "%userlogin_task%" /tr "%userlogin_script%" /sc onlogon /f
	if errorlevel 1 (
		echo [31mERROR     : "%userlogin_task%" could not be created [0m
		exit /b 2
	)
	echo [33mWARNING   : The task runs for %USERNAME% alone. Open taskschd.msc and change its principal to the Users group [0m
	exit /b 1
)

exit /b 2
