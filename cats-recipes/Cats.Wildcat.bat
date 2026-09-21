@echo off
setlocal enabledelayedexpansion

rem  CATS_HOME is the copy this run reads its .bat files from, see cats-shadow.bat
if not defined CATS_HOME set "CATS_HOME=C:\Admin\Scripts"

rem ============================================================
rem  Wildcat
rem  cats clean wildcat (or cats clean cats.wildcat) turns a
rem  machine just imaged from a Copy Cat template - built on a
rem  Proxmox VM - into a Wild Cat on real hardware.
rem
rem  Order matters: the real hardware drivers go in first, so the
rem  machine keeps a working network and disk driver once the
rem  VirtIO guest drivers carried by the Proxmox image are removed.
rem  Replaces cats clean wildcat-deploy, which only ran that removal.
rem
rem    cats clean wildcat
rem
rem  The steps are not run one after the other inside this file:
rem  they are handed to cats-resume.bat as a chain, and the chain
rem  is what survives the restarts the drivers and the updates
rem  ask for. Whoever signs in as an administrator after a
rem  restart picks it up without typing anything. The order is
rem  the same it always was:
rem    1. cats install Drivers      - the drivers this machine needs
rem    2. cats update Scripts       - latest recipes before the rest
rem    3. cats clean Wildcat virtio - the Proxmox guest drivers out
rem    4. cats clean Wildcat gpu    - Intel DSA and NVIDIA, if present
rem    5. cats update Windows       - everything else, until it ends
rem
rem  The two steps that are not a cats verb of their own - the
rem  VirtIO removal and the hardware detection - are sub commands
rem  of this recipe, because a chain is made of things that can
rem  be typed after cats and picked up again after a restart.
rem
rem    cats clean Wildcat virtio    step 3 alone
rem    cats clean Wildcat gpu       step 4 alone
rem ============================================================

set WC_CHAIN=install Drivers+update Scripts+clean Wildcat virtio+clean Wildcat gpu+update Windows

if /I "%~1"=="clean" (

	if /I "%~2"=="virtio" (
		echo [36mRECIPE    : Removing the VirtIO guest drivers of the Proxmox image [0m
		winget uninstall RedHat.VirtIO --accept-source-agreements
		exit /b 0
	)

	if /I "%~2"=="gpu" (
		rem cats install passes the *next package* on the command line as an
		rem argument, so the CPU and the GPU are detected here instead of asking
		rem inteldasa or Nvidia to work it out from an argument that is not theirs
		set WC_INTEL=no
		for /f "delims=" %%i in ('powershell -noprofile -command "if ((Get-CimInstance Win32_Processor).Manufacturer -match 'Intel') { 'yes' } else { 'no' }"') do set WC_INTEL=%%i
		if /I "!WC_INTEL!"=="yes" (
			echo [36mRECIPE    : Intel CPU found, installing Intel Driver and Support Assistant [0m
			call "%CATS_HOME%\cats-install.bat" inteldasa
		) else (
			echo [36mRECIPE    : No Intel CPU, skipping Intel Driver and Support Assistant [0m
		)

		set WC_NVIDIA=no
		for /f "delims=" %%i in ('powershell -noprofile -command "if (Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match 'NVIDIA' }) { 'yes' } else { 'no' }"') do set WC_NVIDIA=%%i
		if /I "!WC_NVIDIA!"=="yes" (
			echo [36mRECIPE    : NVIDIA GPU found, installing the driver [0m
			call "%CATS_HOME%\cats-install.bat" Nvidia
		) else (
			echo [36mRECIPE    : No NVIDIA GPU, skipping the driver [0m
		)

		exit /b 0
	)

	if not "%~2"=="" (
		echo [31mERROR     : Wildcat has no step called %~2 [0m
		echo [94mUSAGE     : cats clean Wildcat, or one step of it: virtio, gpu [0m
		exit /b 2
	)

	echo [36mRECIPE    : Turning this machine into a Wild Cat: %WC_CHAIN% [0m
	echo [94mUSAGE     : it restarts on its own where it has to. Sign in as an administrator afterwards and it carries on [0m
	call "%CATS_HOME%\cats-resume.bat" open "clean Wildcat" "%WC_CHAIN%"
	if errorlevel 2 (
		echo [31mERROR     : the chain was not started, the lines above say why [0m
		exit /b 2
	)

	echo [92mDONE     [96m : Wildcat[0m
	exit /b 0
)

exit /b 2
