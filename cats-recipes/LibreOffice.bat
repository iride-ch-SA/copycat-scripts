@echo off
setlocal enabledelayedexpansion

rem LibreOffice, current release, installed silently in the language of this machine.
rem
rem Why not winget. The winget manifest installs the same MSI but passes none of its language
rem properties, so the machine ends up with whatever the installer's automatic selection makes of
rem it - which on a Windows imaged in one language and used in another is not the language the
rem user reads. The principal reported it as unreliable in that respect on 2026-08-27. This
rem recipe sets the language explicitly instead of hoping for it, which is the whole reason it
rem exists; everything else it does, winget would also do.
rem
rem How the language gets in. On Windows the LibreOffice MSI is multilingual: the mirror carries
rem help packs but no language packs, because every UI language is inside the one installer and
rem is selected at install time through the UI_LANGS property, documented by TDF since 3.5.5.
rem The language is therefore an install parameter here, not a second download - unlike Linux and
rem macOS, where a langpack is a separate file. ps\libreoffice-lookup.ps1 works out which value
rem UI_LANGS must take from the culture Windows reports, and also resolves the current version
rem and its URL: TDF publishes no evergreen URL, every release sits under its own version path.
rem
rem Where the bytes come from. Not from download.documentfoundation.org, or at least not from it
rem alone: the redirector killed the connection on the first field run of this recipe, 2026-08-27,
rem and had refused the agent's machine the same day while four direct TDF mirrors answered. The
rem download therefore goes through ps\tdf-fetch.ps1, which tries the redirector first and then
rem those mirrors, and verifies the Authenticode signature of what arrives before this recipe
rem installs it - the packages are signed by The Document Foundation, so the bytes are checked
rem whichever mirror served them.
rem
rem   cats install LibreOffice
rem
rem Two options, for the operator who needs them. They are not meant for the cats command line -
rem the dispatcher iterates over every argument and would try to install them as packages too -
rem so call the recipe directly:
rem
rem   C:\Admin\Scripts\cats-recipes\LibreOffice.bat install still         the still branch
rem   C:\Admin\Scripts\cats-recipes\LibreOffice.bat install lang de       force the UI language
rem   C:\Admin\Scripts\cats-recipes\LibreOffice.bat install still lang de
rem
rem The recipe is silent, unlike HPSA9 and Nvidia: there is nothing for an operator to choose in
rem the LibreOffice wizard that this recipe does not already decide. Two of those decisions are
rem worth naming. REGISTER_NO_MSO_TYPES=1 keeps LibreOffice from taking over .doc, .xls and .ppt,
rem because a Wild Cat may also carry Microsoft Office - drop that property to let it register
rem them. ISCHECKFORPRODUCTUPDATES=0 turns off the update nag, which on a managed machine points
rem at an upgrade the user cannot perform anyway; `cats install LibreOffice` is the upgrade.

set LO_DIR=C:\Admin\Installers\LibreOffice

if "%~1"=="install" (
	if not exist "%LO_DIR%" ( mkdir "%LO_DIR%" )

	set LO_ARGS=
	if /i "%~2"=="still" ( set LO_ARGS=-Branch previous )
	if /i "%~2"=="lang" ( set LO_ARGS=-Lang "%~3" )
	if /i "%~3"=="lang" ( set LO_ARGS=!LO_ARGS! -Lang "%~4" )

	set LO_ERR=
	set LO_VER=
	set LO_LANG=
	set LO_UILANGS=
	set LO_FILE=
	set LO_URL=
	set LO_RELPATH=
	set LO_HELPFILE=
	set LO_HELPURL=
	set LO_OSUI=

	rem The lookup writes to a file with stderr folded in, and the file is what gets parsed:
	rem for /f on the pipe throws stderr away, so a PowerShell that dies before its first line
	rem of output would leave the recipe able to say only that nothing came back. Nvidia was
	rem shipped that way and the first field run, 2026-08-20, was wasted on it. The file stays
	rem on disk on purpose - it is the evidence for whoever looks at a failure. Every PowerShell
	rem call below follows the same shape, which is also why none of them is read through a
	rem backtick FOR: a pipe or a redirection inside one needs caret escaping that cannot be
	rem tested anywhere but on Windows.
	set "LO_LOG=%LO_DIR%\lookup.log"

	echo [36mRECIPE    : Looking up the current LibreOffice and this machine's language [0m
	powershell -noprofile -executionpolicy bypass -command C:\Admin\Scripts\ps\libreoffice-lookup.ps1 !LO_ARGS! > "!LO_LOG!" 2>&1

	for /f "usebackq tokens=1,* delims==" %%k in ("!LO_LOG!") do (
		if "%%k"=="ERROR" ( set "LO_ERR=%%l" )
		if "%%k"=="VERSION" ( set "LO_VER=%%l" )
		if "%%k"=="LANG" ( set "LO_LANG=%%l" )
		if "%%k"=="UILANGS" ( set "LO_UILANGS=%%l" )
		if "%%k"=="FILE" ( set "LO_FILE=%%l" )
		if "%%k"=="URL" ( set "LO_URL=%%l" )
		if "%%k"=="RELPATH" ( set "LO_RELPATH=%%l" )
		if "%%k"=="HELPFILE" ( set "LO_HELPFILE=%%l" )
		if "%%k"=="HELPURL" ( set "LO_HELPURL=%%l" )
		if "%%k"=="OSUICULTURE" ( set "LO_OSUI=%%l" )
	)

	if not "!LO_ERR!"=="" (
		echo [31mERROR     : !LO_ERR! [0m
		echo [31mERROR     : full lookup output in !LO_LOG! [0m
		exit /b 2
	)

	if "!LO_URL!"=="" (
		echo [31mERROR     : the LibreOffice lookup returned no package. What it did say: [0m
		type "!LO_LOG!"
		echo [31mERROR     : send the lines above, they name the cause [0m
		exit /b 2
	)

	echo [36mRECIPE    : LibreOffice !LO_VER!, Windows reports !LO_OSUI!, UI languages !LO_UILANGS! [0m

	rem What is already on the machine decides whether anything has to be downloaded at all: the
	rem package is around 375 MB, and `cats install LibreOffice` is also the upgrade command, so
	rem it has to be cheap to run on a machine that is already current. The installed version has
	rem a fourth component the published one does not - 26.8.0 ships as 26.8.0.3 - hence a prefix
	rem match and not an equality. The help pack carries its own uninstall entry and is excluded.
	set "LO_STATE=%LO_DIR%\installed.log"
	set "LO_FIND=$k = @(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue); $k = @($k.Where({ $_.DisplayName -like 'LibreOffice*' -and $_.DisplayName -notlike '*Help Pack*' })); if ($k.Count -gt 0) { Write-Output ('INSTALLED=' + $k[0].DisplayVersion) }"

	set LO_HAVE=
	powershell -noprofile -executionpolicy bypass -command "!LO_FIND!" > "!LO_STATE!" 2>&1
	for /f "usebackq tokens=1,* delims==" %%k in ("!LO_STATE!") do (
		if "%%k"=="INSTALLED" ( set "LO_HAVE=%%l" )
	)

	if not "!LO_HAVE!"=="" (
		echo !LO_HAVE!| findstr /b /c:"!LO_VER!" >nul
		if not errorlevel 1 (
			echo [36mRECIPE    : LibreOffice !LO_HAVE! is already installed, nothing to do [0m
			echo [36mRECIPE    : the UI language of an installed copy is not changed by this [0m
			echo [36mRECIPE    : recipe: it is in Tools - Options - Languages and Locales [0m
			exit /b 0
		)
		echo [36mRECIPE    : upgrading from !LO_HAVE! [0m
	)

	set "LO_MSI=%LO_DIR%\!LO_FILE!"
	set "LO_FETCHLOG=%LO_DIR%\fetch.log"

	rem No `if not exist` around this call: whether the package is already on disk is decided by
	rem the fetch script, which verifies the copy it finds instead of trusting its name. A part
	rem file left by an interrupted run is resumed there, and a truncated one is thrown away -
	rem handing a half written 375 MB MSI to msiexec would report the installer as the fault.
	echo [36mRECIPE    : Downloading !LO_FILE! to %LO_DIR%, around 375 MB [0m
	powershell -noprofile -executionpolicy bypass -command C:\Admin\Scripts\ps\tdf-fetch.ps1 -Path "!LO_RELPATH!" -File "!LO_FILE!" -Out "!LO_MSI!" > "!LO_FETCHLOG!" 2>&1

	set LO_SOURCE=
	for /f "usebackq tokens=1,* delims==" %%k in ("!LO_FETCHLOG!") do (
		if "%%k"=="SOURCE" ( set "LO_SOURCE=%%l" )
	)

	if not exist "!LO_MSI!" (
		echo [31mERROR     : the LibreOffice package could not be downloaded. Every source: [0m
		type "!LO_FETCHLOG!"
		echo [31mERROR     : the official address is !LO_URL! [0m
		exit /b 2
	)

	if not "!LO_SOURCE!"=="" (
		echo [36mRECIPE    : downloaded from !LO_SOURCE!, signature verified [0m
	)

	rem start /wait, not a bare msiexec: msiexec hands the work to the Windows Installer service
	rem and can return before the install is over, and the check below would then read the state
	rem of a machine that is still installing.
	echo [36mRECIPE    : Installing LibreOffice !LO_VER! for all users, this takes a few minutes [0m
	start /wait "" msiexec /i "!LO_MSI!" /qn /norestart /l*v "%LO_DIR%\install.log" UI_LANGS=!LO_UILANGS! ALLUSERS=1 ISCHECKFORPRODUCTUPDATES=0 REGISTER_NO_MSO_TYPES=1 RebootYesNo=No
	set loExit=!ERRORLEVEL!

	rem HPSA9 precedent: the exit code is not what decides, the state of the machine is. 3010 is
	rem a success that asks for a restart, and /norestart is why it can appear at all.
	rem
	rem The version is appended to the display name only when the name does not already carry it:
	rem LibreOffice registers as «LibreOffice 26.8.0.3» with the same string as DisplayVersion, so
	rem printing both said «LibreOffice 26.8.0.3 26.8.0.3». Other products do not repeat it.
	set "LO_CHECK=$k = @(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue); $k = @($k.Where({ $_.DisplayName -like 'LibreOffice*' -and $_.DisplayName -notlike '*Help Pack*' })); if ($k.Count -gt 0) { $n = $k[0].DisplayName; $v = $k[0].DisplayVersion; if ($v -and $n -notlike ('*' + $v + '*')) { $n = $n + ' ' + $v }; Write-Host ('RECIPE    : ' + $n + ' is installed') -ForegroundColor Cyan; exit 0 } else { exit 1 }"

	powershell -noprofile -executionpolicy bypass -command "!LO_CHECK!"
	if errorlevel 1 (
		echo [31mERROR     : LibreOffice is not installed, msiexec returned !loExit! [0m
		echo [31mERROR     : the full MSI log is in %LO_DIR%\install.log [0m
		exit /b 2
	)

	if "!loExit!"=="3010" ( echo [33mWARNING   : the installer asks for a restart to finish [0m )

	rem The help pack is optional and never fatal: LibreOffice falls back to the online help, and
	rem not every one of the 126 UI languages has one. It is a separate MSI because help, unlike
	rem the interface, is not bundled in the Windows installer.
	rem
	rem -Optional is what separates «no such help pack» from «the download failed»: a 404 on every
	rem mirror is MISSING, anything else is a failure worth naming. Nothing probes for it first -
	rem the lookup used to, with a HEAD on the redirector, and that HEAD answered «absent» for
	rem every language on a fleet the redirector will not talk to.
	if not "!LO_HELPFILE!"=="" (
		set "LO_HELPMSI=%LO_DIR%\!LO_HELPFILE!"
		set "LO_HELPLOG=%LO_DIR%\fetch-helppack.log"

		echo [36mRECIPE    : Looking for the !LO_LANG! offline help pack [0m
		powershell -noprofile -executionpolicy bypass -command C:\Admin\Scripts\ps\tdf-fetch.ps1 -Path "!LO_RELPATH!" -File "!LO_HELPFILE!" -Out "!LO_HELPMSI!" -Optional > "!LO_HELPLOG!" 2>&1

		set LO_HELPMISS=
		for /f "usebackq tokens=1,* delims==" %%k in ("!LO_HELPLOG!") do (
			if "%%k"=="MISSING" ( set "LO_HELPMISS=1" )
		)

		if exist "!LO_HELPMSI!" (
			echo [36mRECIPE    : Installing the !LO_LANG! offline help [0m
			start /wait "" msiexec /i "!LO_HELPMSI!" /qn /norestart
		) else (
			if "!LO_HELPMISS!"=="1" (
				echo [36mRECIPE    : no offline help pack published for !LO_LANG!, the online help stays [0m
			) else (
				echo [33mWARNING   : the !LO_LANG! help pack could not be downloaded, the online help stays [0m
				echo [33mWARNING   : what each source answered is in !LO_HELPLOG! [0m
			)
		)
	)

	exit /b 0
)

exit /b 2
