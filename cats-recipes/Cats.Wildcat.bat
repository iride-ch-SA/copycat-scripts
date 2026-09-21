@echo off
setlocal enabledelayedexpansion

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
rem  Steps, in order:
rem    1. cats install Drivers  - hardware drivers this machine needs
rem    2. cats update Scripts   - latest recipes before the rest runs
rem    3. remove the VirtIO guest drivers of the Proxmox image
rem    4. an Intel CPU or chipset: cats install inteldasa
rem    5. an NVIDIA GPU: cats install Nvidia
rem    6. cats update Windows   - everything else
rem ============================================================

if /I "%~1"=="clean" (

	echo [36mRECIPE    : Installing the drivers this hardware needs [0m
	call C:\Admin\Scripts\cats-install.bat Drivers

	echo [36mRECIPE    : Updating CopyCat Scripts [0m
	call C:\Admin\Scripts\cats-update.bat Scripts

	echo [36mRECIPE    : Removing the VirtIO guest drivers of the Proxmox image [0m
	winget uninstall RedHat.VirtIO --accept-source-agreements

	rem cats install passes the *next package* on the command line as an
	rem argument, so the CPU and the GPU are detected here instead of asking
	rem inteldasa or Nvidia to work it out from an argument that is not theirs
	set WC_INTEL=no
	for /f "delims=" %%i in ('powershell -noprofile -command "if ((Get-CimInstance Win32_Processor).Manufacturer -match 'Intel') { 'yes' } else { 'no' }"') do set WC_INTEL=%%i
	if /I "!WC_INTEL!"=="yes" (
		echo [36mRECIPE    : Intel CPU found, installing Intel Driver and Support Assistant [0m
		call C:\Admin\Scripts\cats-install.bat inteldasa
	) else (
		echo [36mRECIPE    : No Intel CPU, skipping Intel Driver and Support Assistant [0m
	)

	set WC_NVIDIA=no
	for /f "delims=" %%i in ('powershell -noprofile -command "if (Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match 'NVIDIA' }) { 'yes' } else { 'no' }"') do set WC_NVIDIA=%%i
	if /I "!WC_NVIDIA!"=="yes" (
		echo [36mRECIPE    : NVIDIA GPU found, installing the driver [0m
		call C:\Admin\Scripts\cats-install.bat Nvidia
	) else (
		echo [36mRECIPE    : No NVIDIA GPU, skipping the driver [0m
	)

	echo [36mRECIPE    : Running all Windows updates [0m
	call C:\Admin\Scripts\cats-update.bat Windows

	echo [92mDONE     [96m : Wildcat[0m
	exit /b 0
)

exit /b 2
