@echo off
setlocal enabledelayedexpansion

rem  CATS_HOME is the copy this run reads its .bat files from, see cats-shadow.bat
if not defined CATS_HOME set "CATS_HOME=C:\Admin\Scripts"

echo [95mSTARTING [96m : CopyCat Install[0m

rem  A recipe recognised on this command line takes the words that follow it: they are
rem  its arguments and the recipe was already handed all of them, so they must not be
rem  offered to winget as package ids of their own. In cats install Drivers check, check
rem  is an option of the Drivers recipe and not the id of a package. Several packages on
rem  one line still work, because there no recipe is recognised at all: cats install
rem  Chrome Firefox VLC installs the three of them.
set catsRecipeTaken=0

for %%a in (%*) do (
	:: Cats Recipes
	if exist "%CATS_HOME%\cats-recipes\%%a.bat" ( 
		call "%CATS_HOME%\cats-recipes\%%a.bat" install %2 %3 %4 %5 %6 %7 %8 %9
		set catsRecipeTaken=1
	) else (
		if exist "%CATS_HOME%\cats-recipes\Cats.%%a.bat" (
			call "%CATS_HOME%\cats-recipes\Cats.%%a.bat" install %2 %3 %4 %5 %6 %7 %8 %9
			set catsRecipeTaken=1
		) else (
			set isShortCut=0
			:: WinGet ShortCuts
			if /I "%%a"=="Chrome" ( call "%CATS_HOME%\cats-install-winget.bat" Google.Chrome & set isShortCut=1 )
			if /I "%%a"=="Firefox" ( call "%CATS_HOME%\cats-install-winget.bat" Mozilla.Firefox & set isShortCut=1 )
			if /I "%%a"=="VLC" ( call "%CATS_HOME%\cats-install-winget.bat" VideoLAN.VLC & set isShortCut=1 )
			if /I "%%a"=="intelDASA" ( call "%CATS_HOME%\cats-install-winget.bat" Intel.IntelDriverAndSupportAssistant & set isShortCut=1 )
			if /I "%%a"=="gDrive" ( call "%CATS_HOME%\cats-install-winget.bat" Google.GoogleDrive & set isShortCut=1 )
			if /I "%%a"=="qGIS" ( call "%CATS_HOME%\cats-install-winget.bat" OSGeo.QGIS_LTR & set isShortCut=1 )
			if /I "%%a"=="WindowsApp" ( call "%CATS_HOME%\cats-install-winget.bat" Microsoft.WindowsApp & set isShortCut=1 )
			if /I "%%a"=="GWSMO" ( 
				if exist "%CATS_HOME%\cats-recipes\Google.GWSMO.bat" ( 
					call "%CATS_HOME%\cats-recipes\Google.GWSMO.bat" install
				)
				set isShortCut=1 
			)
			if /I "%%a"=="Acrobat" ( 
				if exist "%CATS_HOME%\cats-recipes\Adobe.Acrobat.Reader.bat" ( 
					call "%CATS_HOME%\cats-recipes\Adobe.Acrobat.Reader.bat" install 
				)
				set isShortCut=1 
			)
			
			if !isShortCut! EQU 0 (
				if !catsRecipeTaken! EQU 1 (
					echo [36mRECIPE    : %%a is read as an argument of the recipe above, not as a package [0m
				) else (
					echo [33mWARNING   : Package %%a not found as copycat recipe, trying to pass directly to winget [0m
					call "%CATS_HOME%\cats-install-winget.bat" %%a
				)
			)
		)
	)
)

echo [92mDONE     [96m : CopyCat Install[0m
exit /b 0
