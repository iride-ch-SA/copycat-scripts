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
rem   11. cats clean Wildcat autologon off - and from here on the
rem       machine asks for a sign in again
rem   12. cats prepare Machine          - the random name, which
rem       takes effect at the restart it asks for
rem   13. cats create Machine           - the hardware identifier,
rem       written last and therefore taken on the machine as it
rem       will be delivered
rem
rem  The last two are last, and in this order, on purpose. The
rem  rename wants a restart, and it comes AFTER the automatic
rem  logon is off so that nothing has to auto sign in with a name
rem  that has just changed underneath it - the stored logon
rem  carries the name the machine had when it was configured. The
rem  operator signs in once after that restart, which is the same
rem  visit in which they change the itadmin password by hand, and
rem  the identifier is computed then, on the finished machine.
rem  Worth knowing: the identifier does NOT depend on the machine
rem  name - it is the BIOS serial, the processor id, the MAC
rem  addresses and the serial numbers of memory and disks - so
rem  this order is a matter of procedure, not of arithmetic. What
rem  IS of substance is that it comes after the last restart.
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
rem    cats clean Wildcat virtio      one step alone
rem    cats clean Wildcat gpu         one step alone
rem    cats clean Wildcat restart     ask for a restart and nothing else
rem    cats clean Wildcat autologon on|off   the automatic logon
rem ============================================================

set WC_CHAIN=clean Wildcat autologon on+install Drivers+update Scripts+clean Wildcat restart+clean Wildcat virtio+prepare Drivers infpack yes+clean Wildcat gpu+clean Wildcat restart+install Drivers+update Windows+install Drivers+clean Wildcat autologon off+prepare Machine+create Machine

if /I "%~1"=="clean" (

	if /I "%~2"=="autologon" (
		rem  The automatic logon is what makes a chain of ten steps and several
		rem  restarts run without somebody signing in at each one. It is switched on
		rem  as the first step and off as the last, and cats-resume switches it off
		rem  again whenever a chain ends, however it ends - a machine that leaves for
		rem  a client signing itself in as an administrator is the one outcome of
		rem  this that would really matter.
		rem  The account is itadmin and its password is the one in
		rem  config\autounattend.xml, in this repository on purpose: it is the default
		rem  every machine starts from, and the operator changes it BY HAND at the end
		rem  of the procedure. That change is deliberately not automated - a generated
		rem  password set by a chain nobody is watching is a password nobody can read
		rem  back, and the machine is lost.
		rem  Best effort by construction: if the logon does not happen - a wrong
		rem  password, an ActiveSync policy - the chain is not lost, it waits for an
		rem  administrator to sign in as it did before this existed.
		if /I "%~3"=="off" (
			powershell -noprofile -executionpolicy bypass -command "& %CATS_ROOT%\ps\set-autologon.ps1 -Mode off; exit $LASTEXITCODE"
			if errorlevel 2 (
				echo [31mERROR     : the automatic logon could not be switched off, check it before this machine leaves [0m
				exit /b 2
			)
			exit /b 0
		)
		powershell -noprofile -executionpolicy bypass -command "& %CATS_ROOT%\ps\set-autologon.ps1 -Mode on; exit $LASTEXITCODE"
		if errorlevel 3 (
			echo [33mWARNING   : Autologon is not installed, so every restart of this chain will wait for a sign in [0m
			echo [94mUSAGE     : cats install Cats.Utils puts it in C:\Admin\Apps, and the image is where it belongs [0m
			exit /b 0
		)
		if errorlevel 2 (
			echo [33mWARNING   : the automatic logon is not on, so every restart of this chain will wait for a sign in [0m
			exit /b 0
		)
		exit /b 0
	)

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
