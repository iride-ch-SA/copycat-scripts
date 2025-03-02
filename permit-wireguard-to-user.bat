@echo off
if "%~1"=="" (
	echo ERROR: You must specify a username as first parameter
	exit /b 1
)
SET "PARAM1=%~1"

call C:\Admin\Scripts\set-registry.bat wireguard-nonadmin-users enable

powershell -noprofile -executionpolicy bypass -command "Add-LocalGroupMember -Group 'Network Configuration Operators' -Member %PARAM1%"
