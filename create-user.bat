@echo off
echo [96m----- Create User Script[0m [92mSTARTED[0m [96m-----[0m 

if "%~1"=="" (
	echo [31mERROR: You must specify a username as first parameter [0m
	exit /b 1
)
SET "PARAM1=%~1"

if "%~2"=="" (
	echo [31mERROR: You must specify a password for the user as second parameter [0m
	exit /b 1
)
SET "PARAM2=%~2"

echo [36mCreate the user active and without expiration[0m 
net user /add "%PARAM1%" "%PARAM2%" /expires:never /active:yes

if "%~3"=="Administrators" (
	echo [36mAdding user to Administrators group[0m 
	net localgroup administrators "%PARAM1%" /add
) else (
	echo [36mAdd non-administrative user to Remote Desktop User group[0m 
	C:\Admin\Scripts\ps\set-rdpuser.ps1 "%PARAM1%"
)

echo [96m----- Create User Script[0m [95mENDED[0m [96m-----[0m 
