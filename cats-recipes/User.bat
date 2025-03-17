@echo off
setlocal enabledelayedexpansion

if "%~1"=="create" (
	if "%~2"=="" (
		echo [31mERROR     : You must specify a username as second parameter [0m
		exit /b 1
	)
	SET PARAM1="%~2"
	
	if "%~3"=="" (
		echo [31mERROR     : You must specify a password for the user as third parameter [0m
		exit /b 1
	)
	SET PARAM2="%~3"
	
	echo [36mRECIPE    : Create the user active and without expiration date [0m
	cmd /c net user /add !PARAM1! !PARAM2! /expires:never /active:yes
	
	if "%~4"=="Administrators" (
		echo [36mRECIPE    : Adding user to Administrators group [0m
		net localgroup administrators "!PARAM1!" /add
	) else (
		if not "%~4"=="no-rdp" (
			echo [36mRECIPE    : Adding non-administrative user to Remote Desktop User group [0m
			powershell -noprofile -executionpolicy bypass -command C:\Admin\Scripts\ps\set-rdpuser.ps1 "!PARAM1!"
		)
	)
	exit /b 0
)

exit /b 2