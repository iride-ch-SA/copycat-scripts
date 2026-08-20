@echo off
setlocal enabledelayedexpansion

rem NVIDIA display driver, full package: NVIDIA App and NVIDIA Control Panel included.
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

	echo [36mRECIPE    : Detecting the NVIDIA GPU and looking up its current driver [0m
	for /f "tokens=1,* delims==" %%k in ('powershell -noprofile -executionpolicy bypass -file C:\Admin\Scripts\ps\nvidia-driver-lookup.ps1 !NV_ARGS!') do (
		if "%%k"=="ERROR" ( set "NV_ERR=%%l" )
		if "%%k"=="GPU" ( set "NV_GPU=%%l" )
		if "%%k"=="SERIES" ( set "NV_SERIES=%%l" )
		if "%%k"=="VERSION" ( set "NV_VER=%%l" )
		if "%%k"=="SIZE" ( set "NV_SIZE=%%l" )
		if "%%k"=="FILE" ( set "NV_FILE=%%l" )
		if "%%k"=="URL" ( set "NV_URL=%%l" )
	)

	if not "!NV_ERR!"=="" (
		echo [31mERROR     : !NV_ERR! [0m
		exit /b 2
	)

	if "!NV_URL!"=="" (
		echo [31mERROR     : the NVIDIA driver lookup returned no package, check the network and try again [0m
		exit /b 2
	)

	echo [36mRECIPE    : !NV_GPU! [0m
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
	echo [36mRECIPE    : keep NVIDIA App and NVIDIA Control Panel selected, they are the full package [0m
	"!NV_EXE!"
	set nvExit=!ERRORLEVEL!

	rem The installer returns as soon as its own interface is done, and a driver change may
	rem need a restart before Windows reports it: what follows is information for whoever is
	rem at the screen, not a verdict on the installation.
	echo [36mRECIPE    : Driver version now reported by Windows: [0m
	powershell -noprofile -command "Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match 'NVIDIA' } | ForEach-Object { '  ' + $_.Name + ' - ' + $_.DriverVersion }"

	if not "!nvExit!"=="0" (
		echo [33mWARNING   : the NVIDIA installer returned !nvExit!, check the result on screen [0m
	)

	exit /b 0
)

exit /b 2
