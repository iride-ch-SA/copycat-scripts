@echo off
REM **** Set the background
call C:\Admin\Scripts\set-background.bat

IF EXIST "C:\Admin\Others\%username%.bat" (
	echo Calling local %username%.bat Script
	call C:\Admin\Others\%username%.bat
)

IF EXIST "C:\Admin\Others\userlogin.bat" (
	echo Calling local userlogin.bat Script
	call C:\Admin\Others\userlogin.bat
)
