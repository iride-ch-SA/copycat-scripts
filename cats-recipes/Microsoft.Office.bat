@echo off
setlocal enabledelayedexpansion

if "%~1"=="install" (
	winget list --id Microsoft.Office --accept-source-agreements | find /I "Microsoft 365 Apps for enterprise" > nul
	if !errorlevel! NEQ 0 (
		call C:\Admin\Scripts\cats-install-winget.bat Microsoft.OfficeDeploymentTool --silent
		timeout /t 5 /nobreak > NUL
		if exist "C:\Program Files\OfficeDeploymentTool\setup.exe" (
			if exist "C:\Admin\Others\office.xml" (
				echo [36mMS ODT    : Configuring Office using C:\Admin\Others\office.xml [0m
				"C:\Program Files\OfficeDeploymentTool\setup.exe" /configure C:\Admin\Others\office.xml
				exit /b 0
			) else (
				if exist "C:\Admin\Scripts\config\office.xml" (
					echo [36mMS ODT    : Configuring Office using C:\Admin\Scripts\config\office.xml [0m
					"C:\Program Files\OfficeDeploymentTool\setup.exe" /configure C:\Admin\Scripts\config\office.xml
					exit /b 0
				) else (
					echo [31mERROR     : No configurations files was found to install Office Suite[0m
					exit /b 2
				)
			)
		) else (
			echo [31mERROR     : Something went wrong by installing Office Deployment Tool[0m
			exit /b 2
		)
	) else (
		call "%~f0" update
		exit /b 1
	)
)

if "%~1"=="update" (
	rem Aggiornamento della suite gia installata
	if not exist "C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe" (
		echo [31mERROR     : OfficeC2RClient.exe not found, Office is not a Click-to-Run installation[0m
		exit /b 2
	)
	echo [36mMSOFFICE  : Upgrade of Microsoft 365 Apps started in background [0m
	"C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe" /update user displaylevel=false forceappshutdown=true
	exit /b 0
)

exit /b 2