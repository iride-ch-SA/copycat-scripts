@echo off

echo [95mEXECUTING[96m : CopyCat Scripts[0m

:: Executing cats verbs and parameters
if "%~1"=="" (
	echo [31mERROR     : You must specify a verb as first parameter [0m
	echo [94mUSAGE     : cats install,uninstall,update,prepare,clean,set parameters [0m
) else if "%~1"=="install" (
	:: Check if enough parameters are passed
	if "%~2"=="" (
		echo [31mERROR     : You must specify at least one parameter for verb [91minstall [0m
		echo [94mUSAGE     : cats install package-names [0m
	) else (
		echo [36mCALLING   : cats install %2 %3 %4 %5 %6 %7 %8 %9 [0m
		call C:\Admin\Scripts\cats-install.bat %2 %3 %4 %5 %6 %7 %8 %9
	)
) else if "%~1"=="uninstall" (
	echo [36mCALLING   : cats-uninstall %2 %3 %4 %5 %6 %7 %8 %9 [0m
) else if "%~1"=="update" (
	echo [36mCALLING   : cats-update %2 %3 %4 %5 %6 %7 %8 %9 [0m
) else if "%~1"=="prepare" (
	echo [36mCALLING   : cats-prepare %2 %3 %4 %5 %6 %7 %8 %9 [0m
) else if "%~1"=="clean" (
	echo [36mCALLING   : cats-clean %2 %3 %4 %5 %6 %7 %8 %9 [0m
) else if "%~1"=="set" (
	echo [36mCALLING   : cats-set %2 %3 %4 %5 %6 %7 %8 %9 [0m
)

echo [92mDONE     [96m : CopyCat Scripts[0m
