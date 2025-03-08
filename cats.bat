@echo off

echo [96m----- CopyCat Scripts[0m [92mEXECUTING[0m [96m-----[0m 

:: Executing cats verbs and parameters
if "%~1"=="" (
	echo [31mERROR: You must specify a verb as first parameter [0m
	echo [94mUsage: cats {install|uninstall|update|prepare|clean|set} [parameters] [0m
	exit /b 1
) else if "%~1"=="install" (
	:: Check if enough parameters are passed
	if "%~2"=="" (
		echo [31mERROR: You must specify at least one parameter for verb [91minstall [0m
		echo [94mUsage: cats install [package-name]* [0m
		exit /b 1
	) else (
		shift
		call C:\Admin\Scripts\cats-install.bat "%*"
	)
) else if "%~1"=="uninstall" (
	
) else if "%~1"=="update" (
	
) else if "%~1"=="prepare" (
	
) else if "%~1"=="clean" (
	
) else if "%~1"=="set" (
	
)

echo [96m----- CopyCats Scripts[0m [95mDONE[0m [96m-----[0m 
