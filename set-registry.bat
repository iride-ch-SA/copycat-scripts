@echo off
SET "PARAM1=%~1"
SET "PARAM2=%~2"

IF /I "%PARAM1%"=="news-and-interests" ( 
	IF /I "%PARAM2%"=="disable" ( 
		echo Disable AllowNewsAndInterests
		reg add "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /t REG_DWORD /v AllowNewsAndInterests /d "0" /f 
	)
	IF /I "%PARAM2%"=="enable" ( 
		echo Enable AllowNewsAndInterests
		reg delete "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /v AllowNewsAndInterests /f 
	)
)
