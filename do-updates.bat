REM **** Update Scripts Folder
git --git-dir="C:\Admin\Scripts\.git" --work-tree="C:\Admin\Scripts" pull

REM **** Do WinGet updates
winget upgrade --all --accept-package-agreements --accept-source-agreements

REM **** Update Office 365
"C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe" /update user

REM **** Windows Updates
powershell -command "Import-Module PSWindowsUpdate; Get-WindowsUpdate -Install -AcceptAll -AutoReboot"
