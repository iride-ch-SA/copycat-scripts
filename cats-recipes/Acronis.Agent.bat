@echo off
	powershell -command "(new-object System.Net.WebClient).DownloadFile('https://storage.googleapis.com/01931185-232c-77a5-8e67-8751490ebf3e/CopyCats/Admin/Installers/AcronisSnapDeployAgent64.msi','C:\Admin\Installers\AcronisSnapDeployAgent64.msi')"
	C:\Admin\Installers\AcronisSnapDeployAgent64.msi /quiet
exit /b 0