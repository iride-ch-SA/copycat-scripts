@echo off
setlocal

if /I "%~1"=="create" (
	if "%~2"=="" (
		echo [31mERROR     : You must specify a username as second parameter [0m
		exit /b 1
	)

	rem With no password given the option keywords slide into the password
	rem slot, so the arguments are normalised and the recipe is called again
	if "%~3"=="" (
		call "%~f0" create "%~2" ask
		exit /b
	)
	if /I "%~3"=="Administrators" (
		call "%~f0" create "%~2" ask Administrators "%~4"
		exit /b
	)
	if /I "%~3"=="no-rdp" (
		call "%~f0" create "%~2" ask no-rdp
		exit /b
	)
	if /I "%~3"=="hide" (
		call "%~f0" create "%~2" ask "%~4" hide
		exit /b
	)

	if /I "%~3"=="ask" (
		echo [36mRECIPE    : Create the user, the password is typed without being shown [0m
		powershell -noprofile -executionpolicy bypass -command C:\Admin\Scripts\ps\set-user-password.ps1 "%~2" ask -create
		if errorlevel 1 exit /b 1
	) else (
		if /I "%~3"=="random" (
			echo [36mRECIPE    : Create the user with a generated password [0m
			powershell -noprofile -executionpolicy bypass -command C:\Admin\Scripts\ps\set-user-password.ps1 "%~2" random -create
			if errorlevel 1 exit /b 1
		) else (
			echo [33mWARNING   : The password is on the command line and any process listing can read it. Use ask or random instead [0m
			echo [36mRECIPE    : Create the user active and without expiration date [0m
			cmd /c net user /add "%~2" "%~3" /expires:never /active:yes
		)
	)

	if /I "%~4"=="Administrators" (
		echo [36mRECIPE    : Adding user to Administrators group [0m
		cmd /c net localgroup administrators "%~2" /add
		if /I "%~5"=="hide" (
			echo [36mRECIPE    : Hiding user from login screen [0m
			call "%~f0" prepare "%~2" hide
		)
	) else (
		if /I not "%~4"=="no-rdp" (
			echo [36mRECIPE    : Adding non-administrative user to Remote Desktop User group [0m
			powershell -noprofile -executionpolicy bypass -command C:\Admin\Scripts\ps\set-rdpuser.ps1 "%~2"
		)
	)
	exit /b 0
)

if /I "%~1"=="clean" (
	if "%~2"=="" (
		echo [31mERROR     : You must specify a username as second parameter [0m
		exit /b 1
	)

	rem With no third parameter the password is generated
	if "%~3"=="" (
		call "%~f0" clean "%~2" random
		exit /b
	)

	if /I "%~3"=="ask" (
		echo [36mRECIPE    : Password typed without being shown, account enabled and without expiration date [0m
		powershell -noprofile -executionpolicy bypass -command C:\Admin\Scripts\ps\set-user-password.ps1 "%~2" ask
		if errorlevel 1 exit /b 1
		exit /b 0
	)

	if /I "%~3"=="random" (
		echo [36mRECIPE    : New random password, account enabled and without expiration date [0m
		powershell -noprofile -executionpolicy bypass -command C:\Admin\Scripts\ps\set-user-password.ps1 "%~2" random
		if errorlevel 1 exit /b 1
		exit /b 0
	)

	echo [31mERROR     : The third parameter must be ask or random [0m
	exit /b 1
)

if /I "%~1"=="prepare" (
	if "%~2"=="" (
		echo [31mERROR     : You must specify a username as second parameter [0m
		exit /b 1
	)

	if /I "%~3"=="show" (
		reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" /v "%~2" /f
		exit /b 0
	)

	if /I "%~3"=="hide" (
		reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" /t REG_DWORD /f /d 0 /v "%~2"
		exit /b 0
	)

	echo [31mERROR     : You must specify show or hide as third parameter [0m
	exit /b 1
)

exit /b 2
