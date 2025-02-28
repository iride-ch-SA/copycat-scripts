REM **** Set the background
C:\Admin\Scripts\set-background.bat

@echo on
IF EXIST "C:\Admin\Others\%username%.bat" (
	C:\Admin\Others\%username%.bat
)

IF EXIST "C:\Admin\Others\userlogin.bat" (
	C:\Admin\Others\userlogin.bat
)
