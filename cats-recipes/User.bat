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
		cmd /c net localgroup administrators "!PARAM1!" /add
		if "%~5"=="hide" (
			echo [36mRECIPE    : Hiding user from login screen [0m
			call :hide
		)
	) else (
		if not "%~4"=="no-rdp" (
			echo [36mRECIPE    : Adding non-administrative user to Remote Desktop User group [0m
			powershell -noprofile -executionpolicy bypass -command C:\Admin\Scripts\ps\set-rdpuser.ps1 "!PARAM1!"
		)
	)
	exit /b 0
)

if "%~1"=="prepare" (
	if "%~2"=="" (
		echo [31mERROR     : You must specify a username as second parameter [0m
		exit /b 1
	)
	SET PARAM1="%~2"
	
	if "%~3"=="" (
		echo [31mERROR     : You must specify a verb as third parameter [0m
		exit /b 1
	) else (
		if "%~3"=="show" (
			reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" /v "!PARAM1!" /f
			exit /b 0
		)
		if "%~3"=="hide" (
			:hide
				reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" /t REG_DWORD /f /d 0 /v "!PARAM1!"
				exit /b 0
		)
	)
)

exit /b 2