@echo off
	powershell -command "(new-object System.Net.WebClient).DownloadFile('https://dl.google.com/dl/google-apps-sync/x64/enterprise_gsync.msi','C:\Admin\Installers\enterprise_gsync.msi')"
	C:\Admin\Installers\enterprise_gsync.msi
exit /b 0