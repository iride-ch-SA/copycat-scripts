@echo off

if "%~1"=="install" (
	winget list --id Microsoft.Office | find /I "Microsoft 365 Apps for enterprise" > nul
	if %errorlevel% NEQ 0 (
		call C:\Admin\Scripts\cats-install-winget.bat Microsoft.OfficeDeploymentTool
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
		echo [36mMSOFFICE  : Upgrading %~1 [0m
		"C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe" /update user displaylevel=false forceappshutdown=true
		exit /b 1
	)
)

exit /b 2