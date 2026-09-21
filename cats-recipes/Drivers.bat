@echo off
setlocal enabledelayedexpansion

rem ============================================================
rem  Drivers
rem  cats install Drivers looks at what this machine is actually
rem  missing before it installs anything: Windows itself lists
rem  the devices whose driver is missing or not starting, and
rem  only a package under C:\Admin\Drivers that claims one of
rem  *those* devices is installed. A driver library that fits no
rem  device of this machine is left where it is.
rem
rem  The folder is the one the other driver recipes already
rem  write into - HPSA9 puts its SoftPaq in C:\Admin\Drivers\HP,
rem  Nvidia its package in C:\Admin\Drivers\Nvidia - plus
rem  whatever an operator has copied or unpacked there. Only
rem  .inf packages can be installed unattended; a vendor .exe is
rem  named on the console and stays for the operator to run.
rem
rem  The work is done by ps\driver-scan.ps1: the device
rem  enumeration, the inf reading and pnputil live there, where
rem  none of it has to be quoted twice.
rem
rem    cats install Drivers
rem    cats install Drivers check     report only, install nothing
rem
rem  A driver that asks for a restart before it is fully in
rem  charge does not restart the machine here: cats-resume.bat is
rem  told that a restart is needed, and the chain this recipe is
rem  part of orders it once it has written down what is left. Run
rem  by hand, outside a chain, nothing restarts and the machine
rem  is left for the operator to restart.
rem
rem  Exit codes: 0 a driver was installed, 1 every device already
rem  had a working driver, 2 an installation failed, 3 a device
rem  needs a driver and the library has nothing that fits it.
rem ============================================================

set DRV_DIR=C:\Admin\Drivers
set DRV_ARGS=

if /I "%~1"=="install" (

	rem cats install passes the *next package* of the command line as this
	rem argument, so only the word this recipe knows is taken as an option.
	rem Delayed expansion, or the value set inside this block would not be
	rem read back inside the same block
	if /I "%~2"=="check" ( set DRV_ARGS=-Check )

	echo [36mRECIPE    : Checking which devices need a driver, and what %DRV_DIR% has for them [0m

	rem -command, not -file: the wiki prescribes it for this repository. The
	rem trailing exit re-raises the code, which -command alone flattens to 1
	powershell -noprofile -executionpolicy bypass -command "& C:\Admin\Scripts\ps\driver-scan.ps1 -Path '%DRV_DIR%' !DRV_ARGS!; exit $LASTEXITCODE"

	rem errorlevel is greater-or-equal, so the codes are asked top down
	if errorlevel 4 (
		echo [36mRECIPE    : Drivers installed, and a restart is needed before they are fully in charge [0m
		rem again: the devices this machine is still missing a driver for
		rem can only be counted once the ones just installed are in charge
		call C:\Admin\Scripts\cats-resume.bat request again
		exit /b 0
	)
	if errorlevel 3 (
		echo [33mWARNING   : A device needs a driver and %DRV_DIR% has nothing that fits it, see the lines above [0m
		exit /b 3
	)
	if errorlevel 2 (
		echo [31mERROR     : A driver package failed to install, the reason is in the lines above [0m
		exit /b 2
	)
	if errorlevel 1 (
		echo [36mRECIPE    : No driver was needed on this machine [0m
		exit /b 1
	)

	echo [92mDONE     [96m : Drivers installed from %DRV_DIR%[0m
	exit /b 0
)

exit /b 2
