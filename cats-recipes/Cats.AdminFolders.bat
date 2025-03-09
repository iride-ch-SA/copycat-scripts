@echo off

if "%~1"=="prepare" (
	echo [36mRECIPE    : Preparing/Upgrading C:\Admin folder structure [0m
	if not exist "C:\Admin" ( mkdir C:\Admin )
	if exist "C:\Admin" ( echo [32mRECIPE    : C:\Admin OK [0m ) 
	else ( echo [31mRECIPE    : C:\Admin NOT PRESENT [0m [0m )
	
	if not exist "C:\Admin\Apps" ( mkdir C:\Admin\Apps )
	if exist "C:\Admin\Apps" ( echo [32mRECIPE    : C:\Admin\Apps OK [0m ) 
	else ( echo [31mRECIPE    : C:\Admin\Apps NOT PRESENT [0m [0m )
	
	if not exist "C:\Admin\Drivers" ( mkdir C:\Admin\Drivers )
	if exist "C:\Admin\Drivers" ( echo [32mRECIPE    : C:\Admin\Drivers OK [0m ) 
	else ( echo [31mRECIPE    : C:\Admin\Drivers NOT PRESENT [0m [0m )
	
	if not exist "C:\Admin\Installers" ( mkdir C:\Admin\Installers )
	if exist "C:\Admin\Installers" ( echo [32mRECIPE    : C:\Admin\Installers OK [0m ) 
	else ( echo [31mRECIPE    : C:\Admin\Installers NOT PRESENT [0m [0m )
	
	if not exist "C:\Admin\Others" ( mkdir C:\Admin\Others )
	if exist "C:\Admin\Others" ( echo [32mRECIPE    : C:\Admin\Others OK [0m ) 
	else ( echo [31mRECIPE    : C:\Admin\Others NOT PRESENT [0m [0m )
	exit /b 0
)

exit /b 2