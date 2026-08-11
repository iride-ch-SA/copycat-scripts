@echo off

if "%~1"=="install" (
	if not exist "C:\Admin\Apps" ( mkdir C:\Admin\Apps )

	echo [36mRECIPE    : Downloading TeamViewer QuickSupport [0m
	powershell -command "(new-object System.Net.WebClient).DownloadFile('https://download.teamviewer.com/download/TeamViewerQS.exe','C:\Admin\Apps\TeamViewerQS.exe')"

	if not exist "C:\Admin\Apps\TeamViewerQS.exe" (
		echo [33mWARNING   : Direct download failed, falling back to winget [0m
		call C:\Admin\Scripts\cats-install-winget.bat TeamViewer.TeamViewer.QuickSupport --location C:\Admin\Apps
	)

	if not exist "C:\Admin\Apps\TeamViewerQS.exe" (
		echo [31mERROR     : TeamViewer QuickSupport could not be obtained, nothing was installed [0m
		exit /b 2
	)

	echo [36mRECIPE    : Granting all users the right to run it [0m
	call C:\Admin\Scripts\set-permissions.bat teamviewerqs

	echo [36mRECIPE    : Creating Desktop shortcut for all users [0m
	powershell -noprofile -executionpolicy bypass -command "$s = (New-Object -ComObject WScript.Shell).CreateShortcut('C:\Users\Public\Desktop\TeamViewer QuickSupport.lnk'); $s.TargetPath = 'C:\Admin\Apps\TeamViewerQS.exe'; $s.IconLocation = 'C:\Admin\Apps\TeamViewerQS.exe,0'; $s.Description = 'TeamViewer QuickSupport - remote assistance by iride.ch'; $s.Save()"

	if not exist "C:\Users\Public\Desktop\TeamViewer QuickSupport.lnk" (
		echo [33mWARNING   : the shortcut was not created, TeamViewer QuickSupport stays available in C:\Admin\Apps [0m
		exit /b 1
	)

	exit /b 0
)

exit /b 2
