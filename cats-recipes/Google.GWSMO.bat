@echo off

if "%~1"=="install" (
	echo [36mRECIPE    : Downloading Google Workspace Sync for Microsoft Outlook [0m
	powershell -command "(new-object System.Net.WebClient).DownloadFile('https://dl.google.com/dl/google-apps-sync/x64/enterprise_gsync.msi','C:\Admin\Installers\enterprise_gsync.msi')"
	
	echo [36mRECIPE    : Run GWSMO installer [0m
	if exist C:\Admin\Installers\enterprise_gsync.msi (
		C:\Admin\Installers\enterprise_gsync.msi
		exit /b 0
	) else (
		echo [31mERROR     : Something went wrong by downloading GWSMO installer [0m
		exit /b 2
	)
)

exit /b 2