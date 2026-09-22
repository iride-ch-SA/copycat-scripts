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
rem    1. cats install Drivers          - what the image already
rem       carries, installed before anything needs a network: the
rem       network card is itself one of these drivers
rem    2. cats update Scripts           - the newest recipes
rem    3. cats clean Wildcat restart    - so that what follows
rem       runs on those recipes and not on the ones this run
rem       started with, see below
rem    4. cats clean Wildcat virtio     - the Proxmox guest
rem       software out, and its driver packages out of the store
rem    5. cats prepare Drivers infpack yes - the vendor catalogue,
rem       one download, installed without asking
rem    6. cats clean Wildcat gpu        - Intel DSA and NVIDIA, if
rem       present. After the catalogue, not before: the pack
rem       carries the Intel graphics driver, and Intel DSA has
rem       less to find when it is already in
rem    7. cats clean Wildcat restart    - the drivers just put in
rem       take charge, and what hangs off them is enumerated
rem    8. cats install Drivers          - what that enumeration
rem       brought with it
rem    9. cats update Windows           - everything else, until
rem       it finds nothing left
rem   10. cats install Drivers          - once more: Windows
rem       Update installs drivers of its own and brings devices
rem       up with them, and a pass that finds nothing to do says
rem       so and costs one enumeration
rem
rem  Step 3 is not a formality. A run of cats reads its .bat
rem  files from a copy under %TEMP% - see cats-shadow.bat - and
rem  the copy is made once, by the process that opens the chain:
rem  every step of that chain reads the recipes as they were
rem  BEFORE step 2 pulled. Only a restart ends that process, and
rem  the scheduled task then starts cats-resume.bat afresh, which
rem  copies the installation again. Without step 3, step 2
rem  updates the disk and changes nothing about the run that
rem  asked for it.
rem
rem  Step 6 wants a network, which is why it is not first, and it
rem  is the form with one download: the family INF pack instead
rem  of a dozen single packages. On a board that is not an ASUS
rem  NUC the step says so and the chain carries on - a step that
rem  fails does not stop the ones after it.
rem
rem  The steps that are not a cats verb of their own - the VirtIO
rem  removal, the hardware detection, the restart - are sub
rem  commands of this recipe, because a chain is made of things
rem  that can be typed after cats and picked up again after a
rem  restart.
rem
rem    cats clean Wildcat virtio    step 4 alone
rem    cats clean Wildcat gpu       step 6 alone
rem    cats clean Wildcat restart   ask for a restart and nothing else
rem ============================================================

set WC_CHAIN=install Drivers+update Scripts+clean Wildcat restart+clean Wildcat virtio+prepare Drivers infpack yes+clean Wildcat gpu+clean Wildcat restart+install Drivers+update Windows+install Drivers

if /I "%~1"=="clean" (

	if /I "%~2"=="restart" (
		rem  A step of the chain whose whole work is to end the run: what comes
		rem  after it needs a machine that has restarted, either to read the
		rem  recipes step 2 pulled or to see the devices the drivers just
		rem  installed brought up. request writes the flag and returns; the
		rem  restart is cats-resume.bat's to order, and outside a chain nothing
		rem  happens at all
		echo [36mRECIPE    : A restart here, so that what follows runs on the machine the steps above left [0m
		call "%CATS_HOME%\cats-resume.bat" request
		exit /b !errorlevel!
	)

	if /I "%~2"=="virtio" (
		rem  Two removals, because they are two things. winget takes the guest
		rem  software out; the driver packages it left staged in the machine
		rem  driver store are pnputil's, and uninstalling a program has never
		rem  removed them. On real hardware nothing binds them and they are
		rem  inert, but "the guest drivers are out" is either true or it is not
		echo [36mRECIPE    : Removing the VirtIO guest software of the Proxmox image [0m
		winget uninstall RedHat.VirtIO --accept-source-agreements

		echo [36mRECIPE    : And the VirtIO driver packages left behind in the driver store [0m
		powershell -noprofile -executionpolicy bypass -command "& %CATS_ROOT%\ps\remove-virtio.ps1; exit $LASTEXITCODE"
		if errorlevel 3 (
			echo [33mWARNING   : every VirtIO package is still in use by a device: nothing was removed [0m
			exit /b 0
		)
		if errorlevel 2 (
			echo [31mERROR     : the driver store could not be cleaned, the reason is in the lines above [0m
			exit /b 2
		)
		if errorlevel 1 (
			echo [36mRECIPE    : No VirtIO driver package was in the store [0m
			exit /b 0
		)
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
		echo [94mUSAGE     : cats clean Wildcat, or one step of it: virtio, gpu, restart [0m
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
