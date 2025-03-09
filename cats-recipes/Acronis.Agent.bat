@echo off
	if not exist "C:\Program Files\Acronis\SnapDeploy" (
		echo [36mRECIPE    : Downloading Acronis Agent installer [0m
		powershell -command "(new-object System.Net.WebClient).DownloadFile('https://storage.googleapis.com/01931185-232c-77a5-8e67-8751490ebf3e/CopyCats/Admin/Installers/AcronisSnapDeployAgent64.msi','C:\Admin\Installers\AcronisSnapDeployAgent64.msi')"
		echo [36mRECIPE    : Run Acronis Agent installer [0m
		C:\Admin\Installers\AcronisSnapDeployAgent64.msi /quiet
	) else (
		echo [33mWARNING   : Acronis Agent already installed, nothing was done [0m
	)
exit /b 0