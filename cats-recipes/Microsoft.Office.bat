@echo off
	call C:\Admin\Scripts\cats-install-winget.bat  Microsoft.OfficeDeploymentTool
	timeout /t 5 /nobreak > NUL
	if exist "C:\Program Files\OfficeDeploymentTool\setup.exe" (
		if exist "C:\Admin\Scripts\config\office.xml" (
			echo [36mMS ODT    : Configuring Office using C:\Admin\Scripts\config\office.xml [0m
			"C:\Program Files\OfficeDeploymentTool\setup.exe" /configure C:\Admin\Scripts\config\office.xml
		) else (
			echo [33mWARNING   : C:\Admin\Scripts\config\office.xml not found, install without config file [0m
			"C:\Program Files\OfficeDeploymentTool\setup.exe"
		)
	) else (
		echo [31mERROR     : Something went wrong by installing Office Deployment Tool[0m
	)
exit /b 0