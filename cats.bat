@echo off

echo [95mEXECUTING[96m : CopyCat Scripts[0m
:: Check if there is a verb
if "%~1"=="" (
	echo [31mERROR     : You must specify a verb as first parameter [0m
	echo [94mUSAGE     : cats install,uninstall,update,prepare,clean,set,create,backup parameters [0m
	exit /b 2
) else (
	echo [36mCALLING   : cats %~1 %2 %3 %4 %5 %6 %7 %8 %9 [0m
)

:: Check if enough parameters are passed
if "%~2"=="" (
	echo [31mERROR     : You must specify at least one parameter for verb [91m%~1 [0m
	echo [94mUSAGE     : cats %~1 package-names, recipe or shortcut [0m
	exit /b 2
)

:: Executing cats verbs and parameters
if "%~1"=="install" (
	call C:\Admin\Scripts\cats-install.bat %2 %3 %4 %5 %6 %7 %8 %9
)

if "%~1"=="uninstall" (
	echo [36mCALLING   : cats-uninstall %2 %3 %4 %5 %6 %7 %8 %9 [0m
)

if "%~1"=="update" (
	call C:\Admin\Scripts\cats-update.bat %2 %3 %4 %5 %6 %7 %8 %9
)

if "%~1"=="prepare" (
	call C:\Admin\Scripts\cats-prepare.bat %2 %3 %4 %5 %6 %7 %8 %9
)

if "%~1"=="clean" (
	call C:\Admin\Scripts\cats-clean.bat %2 %3 %4 %5 %6 %7 %8 %9
)

if "%~1"=="set" (
	echo [36mCALLING   : cats-set %2 %3 %4 %5 %6 %7 %8 %9 [0m
)

if "%~1"=="create" (
	call C:\Admin\Scripts\cats-create.bat %2 %3 %4 %5 %6 %7 %8 %9
)

if "%~1"=="backup" (
	echo [36mCALLING   : cats-backup %2 %3 %4 %5 %6 %7 %8 %9 [0m
	call C:\Admin\Scripts\cats-backup.bat %2 %3 %4 %5 %6 %7 %8 %9
)

echo [92mDONE     [96m : CopyCat Scripts[0m
exit /b 0
