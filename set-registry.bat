@echo off
if "%~1"=="" (
	echo ERROR: You must specify a scope as first parameter
	exit /b 1
)
SET "PARAM1=%~1"

if "%~2"=="" (
	echo ERROR: You must specify a verb as second parameter
	exit /b 1
)
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

IF /I "%PARAM1%"=="aad-users" ( 
	reg delete "HKLM\Software\Policies\Microsoft\Windows\System" /v DontEnumerateConnectedUsers /f
	reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /t REG_DWORD /v dontdisplaylastusername /d "0" /f
	IF /I "%PARAM2%"=="show" (
		reg add "HKLM\Software\Policies\Microsoft\Windows\System" /t REG_DWORD /v EnumerateLocalUsers /d "1" /f
	) 
	IF /I "%PARAM2%"=="hide" (
		reg delete "HKLM\Software\Policies\Microsoft\Windows\System" /v EnumerateLocalUsers /f
	) 
)

IF /I "%PARAM1%"=="local-user" ( 
	if "%~3"=="" (
		echo ERROR: You must specify a user name as third parameter
		exit /b 1
	)
	SET "PARAM3=%~3"
	
	reg delete "HKLM\Software\Policies\Microsoft\Windows\System" /v DontEnumerateConnectedUsers /f
	reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /t REG_DWORD /v dontdisplaylastusername /d "0" /f
	IF /I "%PARAM2%"=="show" ( 
		reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" /v "%PARAM3%" /f
	)
	IF /I "%PARAM2%"=="hide" ( 
		reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" /t REG_DWORD /f /d 0 /v "%PARAM3%"
	)
)
