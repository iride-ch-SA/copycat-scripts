@echo off
	call C:\Admin\Scripts\cats-install-winget.bat Microsoft.Sysinternals.BGInfo --location C:\Admin\Apps\ 
	call C:\Admin\Scripts\set-permissions.bat bginfo
exit /b 0