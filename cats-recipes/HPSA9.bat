@echo off

if "%~1"=="install" (
	if not exist "C:\Admin\Drivers\HP" ( mkdir C:\Admin\Drivers\HP )

	if not exist "C:\Admin\Drivers\HP\HPSA9.exe" (
		echo [36mRECIPE    : Downloading HP Support Assistant [0m
		powershell -command "(new-object System.Net.WebClient).DownloadFile('https://ftp.hp.com/pub/softpaq/sp163001-163500/sp163238.exe','C:\Admin\Drivers\HP\HPSA9.exe')"
	)

	if not exist "C:\Admin\Drivers\HP\HPSA9.exe" (
		echo [31mERROR     : HP Support Assistant installer could not be downloaded [0m
		exit /b 2
	)

	echo [36mRECIPE    : Extracting HP Support Assistant [0m
	"C:\Admin\Drivers\HP\HPSA9.exe" /s /e /f "C:\Admin\Drivers\HP\HPSA9"

	if not exist "C:\Admin\Drivers\HP\HPSA9\InstallHPSA.exe" (
		echo [31mERROR     : Extraction failed, HP Support Assistant was not installed [0m
		exit /b 2
	)

	echo [36mRECIPE    : Installing HP Support Assistant [0m
	"C:\Admin\Drivers\HP\HPSA9\InstallHPSA.exe" /S /v/qn

	exit /b 0
)

exit /b 2
