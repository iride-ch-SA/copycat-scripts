@echo off
setlocal enabledelayedexpansion

rem  CATS_ROOT is where cats is installed, see cats-shadow.bat
if not defined CATS_ROOT set "CATS_ROOT=C:\Admin\Scripts"

rem ONLYOFFICE Desktop Editors, current release, installed silently for all users in the language
rem of this machine.
rem
rem Why not winget. The winget package installs the same MSI without its LOCALE property, so the
rem editors start in English whatever the machine reads, and it gives no say over which file
rem types the editors take over. This recipe sets both, the same reasons LibreOffice has a recipe
rem of its own.
rem
rem Where the package comes from. ps\onlyoffice-fetch.ps1 reads appcast.json, the feed the
rem editors' own updater reads, which gives the current version and the MSI for each architecture
rem with its MD5. It compares the version with what is installed, downloads from
rem download.onlyoffice.com or GitHub, and checks the MD5 and that the package is signed by
rem Ascensio System SIA before this recipe installs it.
rem
rem   cats install OnlyOffice
rem
rem One option, for the operator who needs it. As with LibreOffice it is not meant for the cats
rem command line, which would try to install it as a package too, so call the recipe directly:
rem
rem   C:\Admin\Scripts\cats-recipes\OnlyOffice.bat install lang de-DE     force the UI language
rem
rem The language applies to an install or an upgrade. A machine that already has the current
rem version is left alone, and the language of a copy already there is changed in the editors
rem themselves, per user.
rem
rem What the recipe decides in place of the wizard:
rem   LOCALE           the UI language, written by the MSI to the registry for the machine and
rem                    for the installing user; a user can still change it in the editors
rem   REGISTER_*=0     for the Microsoft Office formats, because a Wild Cat may also carry
rem                    Microsoft Office; the open formats, PDF and the rest stay registered
rem   NOASSOCHECK=1    the editors stop asking at start up to become the default application
rem   UPDATE_SERVICE=0 no update service and no update check, which is the MSI default and is
rem                    set here so that it stays so: `cats install OnlyOffice` is the upgrade
rem
rem A copy installed earlier with the .exe installer is a different kind of install, and the MSI
rem refuses to run over it: uninstall it first.

set OO_DIR=C:\Admin\Installers\OnlyOffice

if /I "%~1"=="install" (
	if not exist "%OO_DIR%" ( mkdir "%OO_DIR%" )

	set OO_ARGS=
	if /i "%~2"=="lang" ( set OO_ARGS=-Lang "%~3" )

	set OO_ERR=
	set OO_VER=
	set OO_LOCALE=
	set OO_OSUI=
	set OO_HAVE=
	set OO_CURRENT=
	set OO_MSI=
	set OO_SOURCE=

	rem Read from a file with stderr folded in, not from a pipe, for the reason given in
	rem LibreOffice.bat: the file is what tells whoever looks at a failure what went wrong.
	set "OO_LOG=%OO_DIR%\fetch.log"

	echo [36mRECIPE    : Looking up the current ONLYOFFICE and downloading it if needed, around 400 MB [0m
	powershell -noprofile -executionpolicy bypass -command %CATS_ROOT%\ps\onlyoffice-fetch.ps1 -Out "%OO_DIR%" !OO_ARGS! > "!OO_LOG!" 2>&1

	for /f "usebackq tokens=1,* delims==" %%k in ("!OO_LOG!") do (
		if /I "%%k"=="ERROR" ( set "OO_ERR=%%l" )
		if /I "%%k"=="VERSION" ( set "OO_VER=%%l" )
		if /I "%%k"=="LOCALE" ( set "OO_LOCALE=%%l" )
		if /I "%%k"=="OSUICULTURE" ( set "OO_OSUI=%%l" )
		if /I "%%k"=="INSTALLED" ( set "OO_HAVE=%%l" )
		if /I "%%k"=="CURRENT" ( set "OO_CURRENT=%%l" )
		if /I "%%k"=="FILE" ( set "OO_MSI=%%l" )
		if /I "%%k"=="SOURCE" ( set "OO_SOURCE=%%l" )
	)

	if not "!OO_ERR!"=="" (
		echo [31mERROR     : !OO_ERR! [0m
		echo [31mERROR     : full output in !OO_LOG! [0m
		exit /b 2
	)

	if "!OO_CURRENT!"=="1" (
		echo [36mRECIPE    : ONLYOFFICE !OO_HAVE! is already installed, nothing to do [0m
		exit /b 1
	)

	if "!OO_MSI!"=="" (
		echo [31mERROR     : the ONLYOFFICE lookup returned no package. What it did say: [0m
		type "!OO_LOG!"
		exit /b 2
	)
	if not exist "!OO_MSI!" (
		echo [31mERROR     : the ONLYOFFICE package could not be downloaded. Every source: [0m
		type "!OO_LOG!"
		exit /b 2
	)

	if not "!OO_HAVE!"=="" ( echo [36mRECIPE    : upgrading from !OO_HAVE! [0m )
	if not "!OO_SOURCE!"=="" ( echo [36mRECIPE    : downloaded from !OO_SOURCE!, MD5 and signature verified [0m )
	echo [36mRECIPE    : ONLYOFFICE !OO_VER!, Windows reports !OO_OSUI!, UI language !OO_LOCALE! [0m

	set "OO_NOMSO=REGISTER_DOC=0 REGISTER_DOCM=0 REGISTER_DOCX=0 REGISTER_DOT=0 REGISTER_DOTM=0 REGISTER_DOTX=0"
	set "OO_NOMSO=!OO_NOMSO! REGISTER_XLS=0 REGISTER_XLSB=0 REGISTER_XLSM=0 REGISTER_XLSX=0 REGISTER_XLT=0 REGISTER_XLTM=0 REGISTER_XLTX=0"
	set "OO_NOMSO=!OO_NOMSO! REGISTER_PPT=0 REGISTER_PPTM=0 REGISTER_PPTX=0 REGISTER_POT=0 REGISTER_POTM=0 REGISTER_POTX=0"
	set "OO_NOMSO=!OO_NOMSO! REGISTER_PPS=0 REGISTER_PPSM=0 REGISTER_PPSX=0"

	rem start /wait for the reason given in LibreOffice.bat: msiexec can return before the
	rem Windows Installer service is done. RUNAPPLICATION=0 because nobody is at a silent install
	rem to use the editors it would open.
	echo [36mRECIPE    : Installing ONLYOFFICE !OO_VER! for all users, this takes a few minutes [0m
	start /wait "" msiexec /i "!OO_MSI!" /qn /norestart /l*v "%OO_DIR%\install.log" ALLUSERS=1 LOCALE=!OO_LOCALE! UPDATE_SERVICE=0 NOASSOCHECK=1 RUNAPPLICATION=0 !OO_NOMSO!
	set ooExit=!ERRORLEVEL!

	rem The state of the machine decides, not the exit code; 3010 is a success asking for a
	rem restart. The version is in the display name already, «ONLYOFFICE 10.0.0.169 (x64)».
	set "OO_CHECK=$k = @(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue); $k = @($k.Where({ $_.DisplayName -like 'ONLYOFFICE*' -and ([string] $_.DisplayVersion).StartsWith($env:OO_VER) })); if ($k.Count -gt 0) { Write-Host ('RECIPE    : ' + $k[0].DisplayName + ' is installed') -ForegroundColor Cyan; exit 0 } else { exit 1 }"

	powershell -noprofile -executionpolicy bypass -command "!OO_CHECK!"
	if errorlevel 1 (
		echo [31mERROR     : ONLYOFFICE !OO_VER! is not installed, msiexec returned !ooExit! [0m
		echo [31mERROR     : the full MSI log is in %OO_DIR%\install.log [0m
		exit /b 2
	)

	if "!ooExit!"=="3010" ( echo [33mWARNING   : the installer asks for a restart to finish [0m )
	exit /b 0
)

exit /b 2
