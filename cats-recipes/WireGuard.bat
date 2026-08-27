@echo off
setlocal

if /I "%~1"=="install" (
	call C:\Admin\Scripts\cats-install-winget.bat WireGuard.WireGuard
	exit /b 0
)

if /I "%~1"=="prepare" (
	if "%~2"=="" (
		echo [31mERROR     : You must specify a username, or users to scan the whole machine [0m
		echo [94mUSAGE     : cats prepare WireGuard username, or cats prepare WireGuard users [0m
		echo [94mUSAGE     : an Entra account is named as AzureAD\user@tenant, a domain one as DOMAIN\user [0m
		exit /b 2
	)

	echo [36mRECIPE    : Allowing the WireGuard user interface to non-administrators [0m
	call C:\Admin\Scripts\set-registry.bat wireguard-nonadmin-users enable

	rem The value is read back: without elevation the write above fails
	rem and reg says so on its own line, which is easy to scroll past
	reg query "HKLM\SOFTWARE\WireGuard" /v LimitedOperatorUI 2>nul | find /i "0x1" >nul
	if errorlevel 1 (
		echo [31mERROR     : LimitedOperatorUI is not set under HKLM\SOFTWARE\WireGuard, run this from an elevated prompt [0m
		exit /b 2
	)
	echo [32mRECIPE    : LimitedOperatorUI is set [0m

	rem A helper called with -command hands back 1 for any failure it meets,
	rem whatever code it exited with, so the code is re-raised explicitly
	if /I "%~2"=="users" (
		echo [36mRECIPE    : Looking for the non-administrative accounts of this machine [0m
		powershell -noprofile -executionpolicy bypass -command "& C:\Admin\Scripts\ps\wireguard-operators.ps1 -all; exit $LASTEXITCODE"
	) else (
		rem The name travels in the environment: it is quoted once, by nobody,
		rem and a quote or a space in it cannot reach the PowerShell parser
		set "WG_MEMBER=%~2"
		powershell -noprofile -executionpolicy bypass -command "& C:\Admin\Scripts\ps\wireguard-operators.ps1 -username $env:WG_MEMBER; exit $LASTEXITCODE"
	)
	if errorlevel 2 exit /b 2

	echo [36mRECIPE    : WireGuard shows the tunnels to an operator after the next sign-out and sign-in [0m
	exit /b 0
)

exit /b 2
