@echo off
winget search %~1 | findstr /I "%~1" > nul
if !errorlevel! neq 0 (
	echo [31mERROR     : Package %~1 cannot be found in winget. [0m
	exit /b 2
) else (
	winget list --id %~1 | findstr /I "%~1" > nul
	if !errorlevel! neq 0 (
		echo [36mWINGET    : Installing %~1 [0m
		winget install %~1 --accept-package-agreements --accept-source-agreements
		exit /b 0
	) else (
		echo [36mWINGET    : Upgrading %~1 [0m
		winget upgrade %~1
		exit /b 1
	)
)