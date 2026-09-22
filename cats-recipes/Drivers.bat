@echo off
setlocal enabledelayedexpansion

rem  CATS_HOME is the copy this run reads its .bat files from, see cats-shadow.bat
rem  CATS_ROOT is where cats is installed, see cats-shadow.bat
if not defined CATS_ROOT set "CATS_ROOT=C:\Admin\Scripts"
if not defined CATS_HOME set "CATS_HOME=%CATS_ROOT%"

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
rem  cats prepare Drivers fills that folder first, on an ASUS
rem  NUC: it reads the board model out of SMBIOS, asks the ASUS
rem  catalogue what it has for that model, takes what this
rem  machine is actually missing and unpacks it under
rem  C:\Admin\Drivers\ASUS. It then offers to run the install
rem  above, because on a machine in posa that is always what
rem  comes next.
rem
rem    cats prepare Drivers                 fetch, then ask
rem    cats prepare Drivers check           report only, fetch nothing
rem    cats prepare Drivers all             whole catalogue, not just what is missing
rem    cats prepare Drivers force           fetch again what is already there
rem    cats prepare Drivers noinstall       fetch only, do not offer to install
rem    cats prepare Drivers yes             install straight away, without asking
rem    cats prepare Drivers model <sku>     ask the catalogue for another model name
rem    cats prepare Drivers max <mb>        raise the size ceiling, 1024 MB by default
rem    cats prepare Drivers infpack         the family pack INSTEAD of the single packages
rem    cats prepare Drivers noinfpack       never take it, whatever is missing
rem
rem  The family INF pack is the archive of over a gigabyte that
rem  holds the drivers of a whole NUC family. It is not fetched
rem  with the rest, because a posa does not wait for it by
rem  accident - but once the single packages are unpacked the
rem  library is read back with the same matcher cats install
rem  Drivers uses, and a device that nothing can serve sends the
rem  fetch after the pack, size ceiling or not. A catalogue can
rem  have no group for a whole class of device - a NUC15CRBC5 has
rem  none for Audio - with the driver of that device published
rem  only inside the pack, and the machine would end the posa
rem  without it while the console says every package installed.
rem
rem  infpack takes the pack INSTEAD of the single packages, not
rem  on top of them: on that same catalogue it is 1.11 GB against
rem  some 3.3 GB, and seven of the eleven single packages are the
rem  very version the pack already carries. It is the form for
rem  one download and no more - not the form for the most recent
rem  driver of every part, because three singles are newer than
rem  what the pack holds. The plain run is the up to date one.
rem
rem  The prompt between the two has a default and a timeout, so a
rem  chain nobody is watching goes on by itself after thirty
rem  seconds - but thirty seconds of a posa spent on a question
rem  nobody will answer is thirty seconds wasted, and the console
rem  reads as if it were waiting for somebody. In a chain, where
rem  the answer is known when the chain is written, use "yes".
rem
rem  A driver that asks for a restart before it is fully in
rem  charge does not restart the machine here: cats-resume.bat is
rem  told that a restart is needed, and the chain this recipe is
rem  part of orders it once it has written down what is left. Run
rem  by hand, outside a chain, nothing restarts and the machine
rem  is left for the operator to restart.
rem
rem  The restart is asked for even when a package failed to
rem  install. A restart pending is not a verdict on the run, it
rem  says the run is not over: a package that failed to stage -
rem  an expired certificate, say, on something no device of this
rem  machine needs - must not take the restart away and end the
rem  chain with a device short. What failed is named on the
rem  console either way.
rem
rem  cats clean Drivers empties the library: everything under
rem  C:\Admin\Drivers goes, the folder itself stays, because the
rem  other driver recipes write into it. The drivers already in
rem  the driver store are not touched - pnputil copied them there,
rem  and what is removed is only the packages they came from.
rem
rem    cats clean Drivers           empty the library
rem    cats clean Drivers list      what it would remove, nothing removed
rem
rem  Exit codes of clean: 0 the library was emptied, 1 there was
rem  nothing in it, 2 something could not be removed.
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
	powershell -noprofile -executionpolicy bypass -command "& %CATS_ROOT%\ps\driver-scan.ps1 -Path '%DRV_DIR%' !DRV_ARGS!; exit $LASTEXITCODE"

	rem errorlevel is greater-or-equal, so the codes are asked top down
	if errorlevel 4 (
		echo [36mRECIPE    : Drivers installed, and a restart is needed before they are fully in charge [0m
		rem again: the devices this machine is still missing a driver for
		rem can only be counted once the ones just installed are in charge
		call "%CATS_HOME%\cats-resume.bat" request again
		exit /b 0
	)
	if errorlevel 3 (
		echo [33mWARNING   : A device needs a driver and %DRV_DIR% has nothing that fits it, see the lines above [0m
		echo [94mUSAGE     : cats prepare Drivers   asks the vendor catalogue for it, family INF pack included [0m
		exit /b 3
	)
	if errorlevel 2 (
		echo [31mERROR     : A driver package failed to install, the reason is in the lines above [0m
		exit /b 2
	)
	if errorlevel 1 (
		echo [36mRECIPE    : Nothing to install: every device on this machine has a working driver [0m
		exit /b 1
	)

	echo [92mDONE     [96m : Drivers installed from %DRV_DIR%[0m
	exit /b 0
)

if /I "%~1"=="prepare" (

	rem  cats prepare passes the whole rest of the command line, so the options are
	rem  read one by one and anything unknown is left alone - the dispatcher hands
	rem  over the same words it also tries to resolve as recipe names
	set PRP_ARGS=
	set PRP_ASK=1
	rem  %1 is the verb, so the options start at %2. No shift here: the arguments of
	rem  this block were expanded when the block was read, and a shift would not be
	rem  seen by the line below
	call :parse %2 %3 %4 %5 %6 %7 %8 %9

	echo [36mRECIPE    : Filling %DRV_DIR% from the ASUS catalogue for this model [0m

	powershell -noprofile -executionpolicy bypass -command "& %CATS_ROOT%\ps\asus-driver-fetch.ps1 -Path '%DRV_DIR%' !PRP_ARGS!; exit $LASTEXITCODE"
	set PRP_CODE=!errorlevel!

	if !PRP_CODE! GEQ 3 (
		echo [33mWARNING   : Nothing was fetched: this machine is not in the ASUS catalogue, see the lines above [0m
		exit /b 3
	)
	if !PRP_CODE! GEQ 2 (
		echo [31mERROR     : The driver library could not be filled, the reason is in the lines above [0m
		exit /b 2
	)
	if !PRP_CODE! GEQ 1 (
		echo [36mRECIPE    : Nothing to fetch: the library already has what this machine needs [0m
	)

	if "!PRP_ASK!"=="0" (
		echo [92mDONE     [96m : Drivers fetched into %DRV_DIR%, run cats install Drivers to install them[0m
		exit /b 0
	)

	rem  Default yes, and a timeout so that a chain that nobody is watching goes on
	rem  by itself rather than waiting for a key that is never pressed. "yes" skips the
	rem  question altogether: in a chain the answer was decided when the chain was written
	if "!PRP_ASK!"=="2" (
		echo [36mRECIPE    : Installing what was fetched, without asking [0m
	) else (
		echo.
		choice /c YN /n /t 30 /d Y /m "Install the drivers now with cats install Drivers? [Y/n] "
		if errorlevel 2 (
			echo [92mDONE     [96m : Drivers fetched into %DRV_DIR%, not installed[0m
			exit /b 0
		)
	)

	call "%CATS_HOME%\cats-recipes\Drivers.bat" install
	exit /b !errorlevel!
)

if /I "%~1"=="clean" (

	if /I "%~2"=="list" (
		echo [36mRECIPE    : What a clean would take out of %DRV_DIR% [0m
		if exist "%DRV_DIR%\" dir /b /a "%DRV_DIR%"
		exit /b 0
	)

	if not exist "%DRV_DIR%\" (
		echo [36mRECIPE    : Nothing to clean: %DRV_DIR% does not exist [0m
		exit /b 1
	)
	rem  findstr "^" matches any line, so it fails only when dir listed nothing:
	rem  a test on the listing itself, whatever language the machine speaks
	dir /b /a "%DRV_DIR%" 2>nul | findstr "^" >nul
	if errorlevel 1 (
		echo [36mRECIPE    : Nothing to clean: %DRV_DIR% is already empty [0m
		exit /b 1
	)

	echo [36mRECIPE    : Emptying %DRV_DIR%, the folder itself stays [0m
	rem  dir /a, not for /d: for /d skips the hidden folders
	for /f "delims=" %%e in ('dir /b /a:d "%DRV_DIR%" 2^>nul') do rmdir /s /q "%DRV_DIR%\%%e" >nul 2>&1
	del /f /q /a "%DRV_DIR%\*" >nul 2>&1

	rem  A vendor package can hold paths longer than 260 characters - the Intel
	rem  DTT one does, see the Implementation note of the wiki - and rmdir may
	rem  stop on those. robocopy is not bound by that limit: mirroring an empty
	rem  folder onto the library purges whatever rmdir left behind
	dir /b /a "%DRV_DIR%" 2>nul | findstr "^" >nul
	if not errorlevel 1 (
		if exist "%DRV_DIR%.empty" rmdir /s /q "%DRV_DIR%.empty" >nul 2>&1
		mkdir "%DRV_DIR%.empty" >nul 2>&1
		robocopy "%DRV_DIR%.empty" "%DRV_DIR%" /mir /r:1 /w:1 /njh /njs /ndl /nfl /nc /ns /np >nul 2>&1
		rmdir /s /q "%DRV_DIR%.empty" >nul 2>&1
	)

	dir /b /a "%DRV_DIR%" 2>nul | findstr "^" >nul
	if not errorlevel 1 (
		echo [31mERROR     : Something in %DRV_DIR% could not be removed, most likely a file in use: [0m
		dir /b /a "%DRV_DIR%"
		exit /b 2
	)

	echo [92mDONE     [96m : %DRV_DIR% is empty[0m
	exit /b 0
)

exit /b 2

rem  One option per call, so that an option this recipe does not know - or a word the
rem  prepare dispatcher passed on from another recipe of the same line - is skipped
rem  instead of being handed to PowerShell
:parse
if "%~1"=="" exit /b 0
if /I "%~1"=="check"     ( set PRP_ARGS=!PRP_ARGS! -Check )
if /I "%~1"=="all"       ( set PRP_ARGS=!PRP_ARGS! -All )
if /I "%~1"=="force"     ( set PRP_ARGS=!PRP_ARGS! -Force )
if /I "%~1"=="infpack"   ( set PRP_ARGS=!PRP_ARGS! -InfPack )
if /I "%~1"=="noinfpack" ( set PRP_ARGS=!PRP_ARGS! -NoInfPack )
if /I "%~1"=="noinstall" ( set PRP_ASK=0 )
if /I "%~1"=="yes"       ( set PRP_ASK=2 )
if /I "%~1"=="model"     ( set PRP_ARGS=!PRP_ARGS! -Model '%~2'& shift )
if /I "%~1"=="max"       ( set PRP_ARGS=!PRP_ARGS! -MaxSizeMB %~2& shift )
shift
goto :parse
