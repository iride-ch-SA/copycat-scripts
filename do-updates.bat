@echo off
SET "PARAM=%~1"

IF /I "%PARAM%"=="git-reset" ( 
	git --git-dir="C:\Admin\Scripts\.git" --work-tree="C:\Admin\Scripts" fetch --all
	git --git-dir="C:\Admin\Scripts\.git" --work-tree="C:\Admin\Scripts" reset --hard origin/main
)

REM **** Update Scripts Folder
git --git-dir="C:\Admin\Scripts\.git" --work-tree="C:\Admin\Scripts" pull

set git-param=0
IF /I "%PARAM%"=="git-only" ( set git-param=1 )
IF /I "%PARAM%"=="git-reset" ( set git-param=1 )
IF "%git-param%"=="1" ( goto :EOF )

REM **** Do WinGet updates
winget upgrade --all --accept-package-agreements --accept-source-agreements

REM **** Update Office 365
"C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe" /update user displaylevel=false forceappshutdown=true

REM **** Windows Updates
powershell -command "Import-Module PSWindowsUpdate; Get-WindowsUpdate -Install -AcceptAll -AutoReboot"
