@echo off

rem  CATS_HOME is the copy this run reads its .bat files from, see cats-shadow.bat
if not defined CATS_HOME set "CATS_HOME=C:\Admin\Scripts"
REM **** Set the background
call "%CATS_HOME%\set-background.bat"

IF EXIST "C:\Admin\Others\%username%.bat" (
	echo Calling local %username%.bat Script
	call C:\Admin\Others\%username%.bat
)

IF EXIST "C:\Admin\Others\userlogin.bat" (
	echo Calling local userlogin.bat Script
	call C:\Admin\Others\userlogin.bat
)
