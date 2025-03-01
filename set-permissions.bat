@echo off
SET "PARAM=%~1"

IF /I "%PARAM%"=="bginfo" ( 
	if exist "C:\Admin\Apps\bginfo.exe" ( 
		icacls "C:\Admin\Apps\bginfo.exe" /grant "Users:(RX)"
	)
)