@echo off
setlocal enabledelayedexpansion

rem  CATS_HOME is the copy this run reads its .bat files from, see cats-shadow.bat
if not defined CATS_HOME set "CATS_HOME=C:\Admin\Scripts"

echo [95mSTARTING [96m : CopyCat Install[0m

for %%a in (%*) do (
	:: Cats Recipes
	if exist "%CATS_HOME%\cats-recipes\%%a.bat" ( 
		call "%CATS_HOME%\cats-recipes\%%a.bat" install %2 %3 %4 %5 %6 %7 %8 %9
	) else (
		if exist "%CATS_HOME%\cats-recipes\Cats.%%a.bat" (
			call "%CATS_HOME%\cats-recipes\Cats.%%a.bat" install %2 %3 %4 %5 %6 %7 %8 %9
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
				echo [33mWARNING   : Package %%a not found as copycat recipe, trying to pass directly to winget [0m
				call "%CATS_HOME%\cats-install-winget.bat" %%a
			)
		)
	)
)

echo [92mDONE     [96m : CopyCat Install[0m
exit /b 0
