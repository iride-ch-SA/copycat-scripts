@echo off
setlocal enabledelayedexpansion

rem NVIDIA display driver, full package, plus NVIDIA App.
rem
rem The driver package carries the display driver and NVIDIA Control Panel, and it does *not*
rem carry NVIDIA App: field report of 2026-08-20, a Wild Cat installed from the
rem quadro-rtx-desktop-notebook package came out without it. The App is a separate NVIDIA
rem download, so the recipe fetches and installs it as a second step - see the end of the
rem install branch and ps\nvidia-app-lookup.ps1.
rem
rem The recipe downloads, it does not install: the wizard is driven by our operator, the same
rem attended arrangement chosen for HPSA9. Nothing is passed to the installer, so it opens
rem NVIDIA's own interface.
rem
rem What the recipe has to work out first is *which* package. NVIDIA publishes no evergreen
rem URL - every driver lives under its own version-numbered path - so the version cannot be
rem hardcoded without going stale, the way the HPSA9 SoftPaq number does. The driver lookup
rem service that answers the nvidia.com download page is queried instead, and it returns the
rem download URL itself: see ps\nvidia-driver-lookup.ps1, which detects the GPU physically
rem present, maps it to its NVIDIA product series and reads the current package out of that
rem answer. The URL is never assembled here.
rem
rem One package serves a whole family: every current professional board, desktop and notebook
rem alike, is served by a single quadro-rtx-desktop-notebook file, and the GeForce line by one
rem desktop file and one notebook file. Nothing therefore has to be picked per model.
rem
rem Optional second argument: the GPU model, for the machine whose adapter Windows cannot name
rem yet - which is precisely the machine that has no driver. It is accepted only when it looks
rem like an NVIDIA model name, because cats install passes the *next package* on the command
rem line as this argument.
rem
rem   cats install nvidia
rem   cats install nvidia "NVIDIA RTX PRO 2000 Blackwell"

set NV_DIR=C:\Admin\Drivers\Nvidia

if "%~1"=="install" (
	if not exist "%NV_DIR%" ( mkdir "%NV_DIR%" )

	set NV_ARGS=
	if not "%~2"=="" (
		echo %~2| findstr /i /c:"NVIDIA" /c:"GeForce" /c:"Quadro" /c:"RTX" >nul
		if not errorlevel 1 ( set NV_ARGS=-Name "%~2" )
	)

	set NV_ERR=
	set NV_GPU=
	set NV_SERIES=
	set NV_VER=
	set NV_SIZE=
	set NV_FILE=
	set NV_URL=

	rem The lookup writes to a file, stderr folded in, and the file is what gets parsed. Reading
	rem the pipe directly - as the first version did - throws stderr away, so a PowerShell that
	rem fails before its first line of output leaves nothing behind and the recipe can only say
	rem that no package came back. That is exactly what the first run on a Wild Cat produced,
	rem 2026-08-20, and the cause was unrecoverable afterwards. The file stays on disk on
	rem purpose: it is the evidence for whoever looks at the failure. -command, not -file,
	rem because that is the form already in exercise in HID.bat and User.bat.
	set "NV_LOG=%NV_DIR%\lookup.log"

	echo [36mRECIPE    : Detecting the NVIDIA GPU and looking up its current driver [0m
	powershell -noprofile -executionpolicy bypass -command C:\Admin\Scripts\ps\nvidia-driver-lookup.ps1 !NV_ARGS! > "!NV_LOG!" 2>&1

	for /f "usebackq tokens=1,* delims==" %%k in ("!NV_LOG!") do (
		if "%%k"=="ERROR" ( set "NV_ERR=%%l" )
		if "%%k"=="GPU" ( set "NV_GPU=%%l" )
		if "%%k"=="SERIES" ( set "NV_SERIES=%%l" )
		if "%%k"=="VERSION" ( set "NV_VER=%%l" )
		if "%%k"=="SIZE" ( set "NV_SIZE=%%l" )
		if "%%k"=="FILE" ( set "NV_FILE=%%l" )
		if "%%k"=="URL" ( set "NV_URL=%%l" )
	)

	if not "!NV_GPU!"=="" ( echo [36mRECIPE    : !NV_GPU! [0m )

	if not "!NV_ERR!"=="" (
		echo [31mERROR     : !NV_ERR! [0m
		echo [31mERROR     : full lookup output in !NV_LOG! [0m
		exit /b 2
	)

	if "!NV_URL!"=="" (
		echo [31mERROR     : the NVIDIA driver lookup returned no package. What it did say: [0m
		type "!NV_LOG!"
		echo [31mERROR     : send the lines above, they name the cause [0m
		exit /b 2
	)

	echo [36mRECIPE    : !NV_SERIES! driver !NV_VER!, !NV_SIZE! [0m

	set "NV_EXE=%NV_DIR%\!NV_FILE!"

	if not exist "!NV_EXE!" (
		echo [36mRECIPE    : Downloading !NV_FILE! to %NV_DIR% [0m
		powershell -noprofile -command "(new-object System.Net.WebClient).DownloadFile('!NV_URL!','!NV_EXE!')"
	)

	if not exist "!NV_EXE!" (
		echo [31mERROR     : the NVIDIA driver package could not be downloaded [0m
		echo [31mERROR     : !NV_URL! [0m
		exit /b 2
	)

	echo [36mRECIPE    : Starting the NVIDIA installer, follow the wizard on screen [0m
	echo [36mRECIPE    : keep NVIDIA Control Panel selected, it comes with the driver [0m
	"!NV_EXE!"
	set nvExit=!ERRORLEVEL!

	rem The installer returns as soon as its own interface is done, and a driver change may
	rem need a restart before Windows reports it: what follows is information for whoever is
	rem at the screen, not a verdict on the installation.
	rem
	rem These two lines are coloured by PowerShell and not by an escape sequence, on purpose. A
	rem graphical installer is free to leave the console's virtual-terminal mode off when it
	rem returns, and the NVIDIA one does: on the run of 2026-08-20 the escape sequences of the
	rem line below reached the screen as text, while every line printed before the installer -
	rem and every line printed after the powershell call below, which turns that mode back on -
	rem came out coloured. Write-Host paints through the console API, which does not depend on
	rem the mode, so it is right either way. Every recipe that prints after an attended
	rem installer has the same exposure.
	powershell -noprofile -command "Write-Host 'RECIPE    : Driver version now reported by Windows:' -ForegroundColor Cyan; Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match 'NVIDIA' } | ForEach-Object { '  ' + $_.Name + ' - ' + $_.DriverVersion }"

	if not "!nvExit!"=="0" (
		powershell -noprofile -command "Write-Host 'WARNING   : the NVIDIA installer returned !nvExit!, check the result on screen' -ForegroundColor Yellow"
	)

	rem ---- NVIDIA App ----------------------------------------------------------------------
	rem
	rem NVIDIA App is on the Microsoft Store (product XP8CLZL93F5Z4P), but that listing is not an
	rem MSIX: it carries no package family name and its installer type is WPM, a pointer to the
	rem same Win32 setup NVIDIA publishes itself. There is therefore nothing to provision the way
	rem HPSA9 is provisioned, and no per-user variant to avoid: the setup is NVI2, the same
	rem installer framework as the driver, and NVI2 installs per machine - Program Files, HKLM,
	rem services - so the App is there for every user of the machine by construction. That is the
	rem "for all users" the principal asked for on 2026-08-20.
	rem
	rem This step is silent, unlike the driver above: the driver wizard is attended because the
	rem operator chooses what the driver installs, while the App has nothing to choose. NVI2 takes
	rem -s and -noreboot. To make it attended instead, drop both switches.
	rem
	rem The exit code is not trusted, HPSA9 precedent: what decides is whether the App is
	rem afterwards present in the machine.

	set "NV_APPCHECK=$k = @(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'NVIDIA App*' }); if ($k.Count -gt 0 -or (Test-Path ($env:ProgramFiles + '\NVIDIA Corporation\NVIDIA app\CEF\NVIDIA app.exe'))) { exit 0 } else { exit 1 }"

	rem The first check names what it found, the one after the install only decides. A bare "already
	rem installed" is not evidence: on the run of 2026-08-20 it appeared on a machine that had come out
	rem of the previous run *without* the App, and nothing in the output said whether an App had really
	rem been installed in between or whether this test answers yes to something the driver leaves
	rem behind. Printing the uninstall entry with its version, or the path that matched, settles that
	rem question the next time instead of raising it again.

	set "NV_APPFOUND=$k = @(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'NVIDIA App*' }); $p = $env:ProgramFiles + '\NVIDIA Corporation\NVIDIA app\CEF\NVIDIA app.exe'; if ($k.Count -gt 0) { $n = $k[0].DisplayName; $v = $k[0].DisplayVersion; if (-not $v) { $v = 'version not declared' }; Write-Host ('RECIPE    : NVIDIA App is already installed, nothing to do: ' + $n + ' ' + $v) -ForegroundColor Cyan; exit 0 } elseif (Test-Path $p) { Write-Host ('RECIPE    : NVIDIA App is already installed, nothing to do: no uninstall entry, found ' + $p) -ForegroundColor Cyan; exit 0 } else { exit 1 }"

	powershell -noprofile -executionpolicy bypass -command "!NV_APPFOUND!"
	if not errorlevel 1 ( exit /b 0 )

	set NV_APPERR=
	set NV_APPVER=
	set NV_APPFILE=
	set NV_APPURL=
	set "NV_APPLOG=%NV_DIR%\nvapp-lookup.log"

	powershell -noprofile -command "Write-Host 'RECIPE    : Looking up the current NVIDIA App installer' -ForegroundColor Cyan"
	powershell -noprofile -executionpolicy bypass -command C:\Admin\Scripts\ps\nvidia-app-lookup.ps1 > "!NV_APPLOG!" 2>&1

	for /f "usebackq tokens=1,* delims==" %%k in ("!NV_APPLOG!") do (
		if "%%k"=="ERROR" ( set "NV_APPERR=%%l" )
		if "%%k"=="APPVERSION" ( set "NV_APPVER=%%l" )
		if "%%k"=="APPFILE" ( set "NV_APPFILE=%%l" )
		if "%%k"=="APPURL" ( set "NV_APPURL=%%l" )
	)

	if not "!NV_APPERR!"=="" (
		powershell -noprofile -command "Write-Host 'ERROR     : !NV_APPERR!' -ForegroundColor Red"
		powershell -noprofile -command "Write-Host 'ERROR     : the driver is installed, NVIDIA App is not. Full output in !NV_APPLOG!' -ForegroundColor Red"
		exit /b 2
	)

	if "!NV_APPURL!"=="" (
		powershell -noprofile -command "Write-Host 'ERROR     : the NVIDIA App lookup returned no installer. What it did say:' -ForegroundColor Red"
		type "!NV_APPLOG!"
		exit /b 2
	)

	set "NV_APPEXE=%NV_DIR%\!NV_APPFILE!"

	if not exist "!NV_APPEXE!" (
		powershell -noprofile -command "Write-Host 'RECIPE    : Downloading NVIDIA App !NV_APPVER! to %NV_DIR%' -ForegroundColor Cyan"
		powershell -noprofile -command "(new-object System.Net.WebClient).DownloadFile('!NV_APPURL!','!NV_APPEXE!')"
	)

	if not exist "!NV_APPEXE!" (
		powershell -noprofile -command "Write-Host 'ERROR     : NVIDIA App could not be downloaded from !NV_APPURL!' -ForegroundColor Red"
		exit /b 2
	)

	powershell -noprofile -command "Write-Host 'RECIPE    : Installing NVIDIA App !NV_APPVER! for all users, this takes a few minutes' -ForegroundColor Cyan"
	"!NV_APPEXE!" -s -noreboot
	set nvAppExit=!ERRORLEVEL!

	powershell -noprofile -executionpolicy bypass -command "!NV_APPCHECK!"
	if errorlevel 1 (
		powershell -noprofile -command "Write-Host 'ERROR     : NVIDIA App is not installed, its setup returned !nvAppExit!' -ForegroundColor Red"
		powershell -noprofile -command "Write-Host 'ERROR     : NVI2 refuses to install while a reboot is pending: restart, then run this recipe again' -ForegroundColor Red"
		powershell -noprofile -command "Write-Host 'ERROR     : or run !NV_APPEXE! by hand and follow the wizard' -ForegroundColor Red"
		exit /b 2
	)

	powershell -noprofile -command "Write-Host 'RECIPE    : NVIDIA App !NV_APPVER! installed for all users' -ForegroundColor Cyan"
	exit /b 0
)

exit /b 2
