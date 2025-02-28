REM **** Set the background
call C:\Admin\Scripts\set-background.bat

@echo on
IF EXIST "C:\Admin\Others\%username%.bat" (
	call C:\Admin\Others\%username%.bat
)

IF EXIST "C:\Admin\Others\userlogin.bat" (
	call C:\Admin\Others\userlogin.bat
)
