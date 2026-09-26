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
rem    1. cats clean Wildcat autologon on - this machine signs
rem       itself in at every restart the chain orders, which is
rem       what lets the chain reach its end with nobody here
rem    2. cats install Drivers          - what the image already
rem       carries, installed before anything needs a network: the
rem       network card is itself one of these drivers
rem    3. cats update Scripts           - the newest recipes
rem    4. cats clean Wildcat restart    - so that what follows
rem       runs on those recipes and not on the ones this run
rem       started with, see below
rem    5. cats clean Wildcat rechain    - the rest of the chain is
rem       written again from the recipe step 3 pulled, see below
rem    6. cats clean Wildcat virtio     - the Proxmox guest
rem       software out, and its driver packages out of the store
rem    7. cats prepare Drivers infpack yes - the vendor catalogue,
rem       one download, installed without asking
rem    8. cats clean Wildcat gpu        - Intel DSA and NVIDIA, if
rem       present. After the catalogue, not before: the pack
rem       carries the Intel graphics driver, and Intel DSA has
rem       less to find when it is already in
rem    9. cats clean Wildcat restart    - the drivers just put in
rem       take charge, and what hangs off them is enumerated
rem   10. cats install Drivers          - what that enumeration
rem       brought with it
rem   11. cats update Windows           - everything else, until
rem       it finds nothing left
rem   12. cats install Drivers          - once more: Windows
rem       Update installs drivers of its own and brings devices
rem       up with them, and a pass that finds nothing to do says
rem       so and costs one enumeration
rem   13. cats clean Microsoft.Windows  - the consumer apps off
rem       and the workplace settings on. After Windows Update, so
rem       nothing an update brings back is left behind, and before
rem       the restart of the rename, at which the settings of the
rem       signed-in user and fast startup take effect. On anything
rem       but Windows 11 it refuses with an error and the chain
rem       carries on
rem   14. cats prepare Machine          - the random name, which
rem       takes effect at the restart it asks for
rem   15. cats create Machine           - the hardware identifier,
rem       taken after that last restart, on the machine as it
rem       will be delivered
rem   16. cats clean Wildcat background - the wallpaper, drawn on
rem       a machine that by now has its final name
rem   17. cats clean Wildcat autologon off - the last act, always
rem
rem  THIS CHAIN ENDS ON ITS OWN. No step of it waits for anybody,
rem  and nothing in it is a half of something an operator finishes
rem  afterwards. What iride.ch does after it - the work that is
rem  particular to the client, the itadmin password changed by
rem  hand as the last step of THAT procedure - is a separate part
rem  of the deployment and this recipe knows nothing about it.
rem
rem  Which is why the automatic logon stays on ACROSS the rename
rem  and is switched off only by the final step. The rename takes
rem  effect at the restart it asks for, and a stored logon carries
rem  a machine name with it: cats-resume.bat asserts the logon
rem  again before every restart it orders, and set-autologon.ps1
rem  writes the name this machine will have AFTER that restart,
rem  not the one it wears while the step runs. So it signs itself
rem  in under its new name and the last three steps run unwatched.
rem
rem  The identifier comes after the last restart, on the finished
rem  machine. It does NOT depend on the machine name - BIOS
rem  serial, processor id, MAC addresses, serial numbers of memory
rem  and disks - so what matters is only that it is taken at the
rem  end, not that it follows the rename.
rem
rem  And autologon off is last for a reason that is not tidiness:
rem  a machine that leaves for a client signing itself in as an
rem  administrator is the one outcome of all this that would
rem  really matter. cats-resume.bat switches it off as well
rem  wherever a chain stops being a chain - finished, cancelled or
rem  stopped at the ceiling - so the guard is not in one place
rem  only.
rem
rem  Steps 4 and 5 are what make step 3 count, and they are two
rem  different problems.
rem
rem  The restart is about the RECIPES. A run of cats reads its
rem  .bat files from a copy under %TEMP% - see cats-shadow.bat -
rem  and the copy is made once, by the process that opens the
rem  chain: every step reads the recipes as they were BEFORE step
rem  3 pulled. Only a restart ends that process, and the
rem  scheduled task then starts cats-resume.bat afresh, which
rem  copies the installation again.
rem
rem  rechain is about the CHAIN ITSELF, which is a different
rem  thing and is not fixed by a restart. The list of steps is
rem  written into the marker WHOLE when the chain is opened, so a
rem  machine whose C:\Admin\Scripts was old at that moment walks
rem  the old list to the end - a step added to this recipe simply
rem  never runs, and nothing says so. rechain hands cats-resume
rem  the tail of the chain as THIS file has it, read after the
rem  restart from the installation step 3 pulled, and cats-resume
rem  writes it over what is left in the marker. Which is why the
rem  chain is declared below in two halves: WC_HEAD is what must
rem  run with the code the machine started with - the network
rem  card, the pull, the restart - and WC_TAIL is what rechain
rem  replaces itself with. The two are the same chain.
rem
rem  And before any of it, opening the chain pulls and starts
rem  itself again once, so that the list written into the marker
rem  comes from the current recipe whenever this machine has a
rem  network. When it has none the pull fails, the chain opens on
rem  the code that is there, and step 5 catches up later.
rem
rem  Step 7 wants a network, which is why it is not first, and it
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
rem    cats clean Wildcat rechain     rewrite the rest of the chain from this file
rem    cats clean Wildcat background  the wallpaper, and nothing else
rem    cats clean Wildcat autologon on|off   the automatic logon
rem
rem  A Wild Cat can also be a virtual machine on Proxmox, and there
rem  the VirtIO drivers are the disk, the network and the guest
rem  agent the machine runs on. That is a chain of its own:
rem
rem    cats clean wildcat vm
rem
rem  the same chain without what is for real hardware only: the
rem  virtio step, which would take out the drivers the machine
rem  stands on, prepare Drivers infpack, which reads the catalogue
rem  of a board a virtual machine does not have, and Intel DSA in
rem  gpu, which finds nothing to look after behind an emulated
rem  chipset. NVIDIA stays: a GPU passed through to the guest is a
rem  real card and wants its driver.
rem
rem  And because typing the plain form on a virtual machine is the
rem  easy mistake, virtio and gpu look for themselves: on a QEMU
rem  or KVM machine virtio refuses and removes nothing, gpu skips
rem  Intel DSA, and opening the plain chain says which form was
rem  meant. The chain is not switched for the operator - which one
rem  runs is what was typed.
rem ============================================================

set WC_HEAD=clean Wildcat autologon on+install Drivers+update Scripts+clean Wildcat restart+clean Wildcat rechain
set WC_TAIL=clean Wildcat virtio+prepare Drivers infpack yes+clean Wildcat gpu+clean Wildcat restart+install Drivers+update Windows+install Drivers+clean Microsoft.Windows+prepare Machine+create Machine+clean Wildcat background+clean Wildcat autologon off
set WC_CHAIN=%WC_HEAD%+%WC_TAIL%

rem  The chain of a Wild Cat that stays a virtual machine, see above. Same
rem  halves, same reasons; rechain vm is what keeps the tail on this form
set WC_HEAD_VM=clean Wildcat autologon on+install Drivers+update Scripts+clean Wildcat restart+clean Wildcat rechain vm
set WC_TAIL_VM=clean Wildcat gpu+clean Wildcat restart+install Drivers+update Windows+install Drivers+clean Microsoft.Windows+prepare Machine+create Machine+clean Wildcat background+clean Wildcat autologon off
set WC_CHAIN_VM=%WC_HEAD_VM%+%WC_TAIL_VM%

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

	if /I "%~2"=="rechain" (
		rem  The chain was written into the marker whole when it was opened, from
		rem  the recipe as it was on the disk THEN. This step hands cats-resume the
		rem  tail as this file has it now - read after a restart, from the
		rem  installation the pull updated - and what is left in the marker is
		rem  written over. Same chain when nothing changed, which is the ordinary
		rem  case and costs a line of console
		echo [36mRECIPE    : Writing the rest of the chain again, from the recipes this machine has now [0m
		if /I "%~3"=="vm" (
			call "%CATS_HOME%\cats-resume.bat" rechain "%WC_TAIL_VM%"
		) else (
			call "%CATS_HOME%\cats-resume.bat" rechain "%WC_TAIL%"
		)
		if errorlevel 2 (
			echo [33mWARNING   : the chain was left as it was, the lines above say why [0m
			exit /b 0
		)
		exit /b 0
	)

	if /I "%~2"=="background" (
		rem  The wallpaper, as a step of its own so that the chain can carry it. It
		rem  comes after prepare Machine on purpose: whatever the BgInfo profile
		rem  draws on it describes the machine as it will be delivered, with the
		rem  name it keeps, and not the one it had while the posa was running
		echo [36mRECIPE    : Setting the desktop background of this machine [0m
		call "%CATS_HOME%\set-background.bat"
		exit /b 0
	)

	if /I "%~2"=="virtio" (
		rem  Two removals, because they are two things. winget takes the guest
		rem  software out; the driver packages it left staged in the machine
		rem  driver store are pnputil's, and uninstalling a program has never
		rem  removed them. On real hardware nothing binds them and they are
		rem  inert, but "the guest drivers are out" is either true or it is not.
		rem  On a virtual machine they are the disk and the network it runs on,
		rem  so there the step refuses, whatever chain or hand typed it
		call :is_vm
		if /I "!WC_VM!"=="yes" (
			echo [33mWARNING   : this is a virtual machine, and the VirtIO drivers are what it runs on: nothing was removed [0m
			echo [94mUSAGE     : cats clean Wildcat vm is the chain for a Wild Cat that stays a virtual machine [0m
			exit /b 0
		)
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
		rem inteldasa or Nvidia to work it out from an argument that is not theirs.
		rem On a virtual machine the processor is the host's and the chipset is
		rem emulated, so Intel DSA would have nothing to look after; a GPU passed
		rem through is a real card, so NVIDIA is looked for all the same
		call :is_vm
		set WC_INTEL=no
		for /f "delims=" %%i in ('powershell -noprofile -command "if ((Get-CimInstance Win32_Processor).Manufacturer -match 'Intel') { 'yes' } else { 'no' }"') do set WC_INTEL=%%i
		if /I "!WC_VM!"=="yes" set WC_INTEL=vm
		if /I "!WC_INTEL!"=="vm" (
			echo [36mRECIPE    : Virtual machine, skipping Intel Driver and Support Assistant [0m
		) else if /I "!WC_INTEL!"=="yes" (
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

	set "WC_FORM="
	if /I "%~2"=="vm" set "WC_FORM=vm"
	if not "%~2"=="" if not defined WC_FORM (
		echo [31mERROR     : Wildcat has no step called %~2 [0m
		echo [94mUSAGE     : cats clean Wildcat, cats clean Wildcat vm, or one step of it: virtio, gpu, restart, rechain, background, autologon [0m
		exit /b 2
	)

	rem  The list of steps is frozen into the marker the moment the chain opens, so
	rem  it is pulled first and this run starts again from the installation the pull
	rem  updated. Once only, and the guard is an environment variable the second run
	rem  inherits. A machine with no network yet - the card is itself one of the
	rem  drivers step 2 installs - fails the pull, opens the chain on the code it has,
	rem  and step 5 rewrites the tail after the restart
	if not defined WC_REFRESHED (
		set "WC_REFRESHED=yes"
		echo [36mRECIPE    : Pulling the recipes before the chain is written down [0m
		call "%CATS_HOME%\cats-update.bat" Scripts
		set "CATS_HOME="
		set "CATS_SCRIPTS_PULLED="
		call "%CATS_ROOT%\cats.bat" clean Wildcat !WC_FORM!
		exit /b !errorlevel!
	)

	rem  Same origin for both forms: opening one over what is left of the other
	rem  replaces it without a question, as opening the same chain again does
	if /I "!WC_FORM!"=="vm" (
		set "WC_CHAIN=%WC_CHAIN_VM%"
		echo [36mRECIPE    : A Wild Cat that stays a virtual machine: the VirtIO drivers stay where they are [0m
		call :is_vm
		if /I not "!WC_VM!"=="yes" (
			echo [33mWARNING   : this does not look like a virtual machine, and the VirtIO packages will stay in its driver store [0m
			echo [94mUSAGE     : cats clean Wildcat, without vm, is the one for real hardware [0m
		)
	) else (
		call :is_vm
		if /I "!WC_VM!"=="yes" (
			echo [33mWARNING   : this is a virtual machine, and the chain below is the one for real hardware [0m
			echo [94mUSAGE     : cats clean Wildcat vm is the one for a virtual machine. The virtio step refuses here all the same [0m
		)
	)

	echo [36mRECIPE    : Turning this machine into a Wild Cat: !WC_CHAIN! [0m
	echo [94mUSAGE     : it restarts on its own where it has to and signs itself back in: it needs nobody until it is done [0m
	call "%CATS_HOME%\cats-resume.bat" open "clean Wildcat" "!WC_CHAIN!"
	if errorlevel 2 (
		echo [31mERROR     : the chain was not started, the lines above say why [0m
		exit /b 2
	)

	echo [92mDONE     [96m : Wildcat[0m
	exit /b 0
)

exit /b 2

rem ============================================================
rem  is_vm sets WC_VM to yes on a QEMU or KVM virtual machine -
rem  what Proxmox runs - and to no everywhere else. Proxmox says
rem  so in the SMBIOS it hands the guest, unless somebody wrote
rem  other values into it by hand: manufacturer QEMU, model
rem  Standard PC. A machine it misses is taken for real hardware,
rem  which is what this recipe did before it looked.
rem ============================================================
:is_vm
set WC_VM=no
for /f "delims=" %%i in ('powershell -noprofile -command "$c = Get-CimInstance Win32_ComputerSystem; if (($c.Manufacturer -match 'QEMU') -or ($c.Model -match 'QEMU|KVM|Standard PC')) { 'yes' } else { 'no' }"') do set WC_VM=%%i
exit /b 0
