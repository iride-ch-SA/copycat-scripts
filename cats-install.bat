@echo off
setlocal enabledelayedexpansion

echo [95mSTARTING [96m : CopyCat Install[0m

for %%a in (%*) do (
	:: Cats Recipes
	if exist C:\Admin\Scripts\cats-recipes\%%a.bat ( 
		call C:\Admin\Scripts\cats-recipes\%%a.bat install %2 %3 %4 %5 %6 %7 %8 %9
	) else (
		if exist C:\Admin\Scripts\cats-recipes\Cats.%%a.bat ((
			call "C:\Admin\Scripts\cats-recipes\Cats.%%a.bat" install %2 %3 %4 %5 %6 %7 %8 %9
		) else (
			set isShortCut=0
			:: WinGet ShortCuts
			if /I "%%a"=="Chrome" ( call C:\Admin\Scripts\cats-install-winget.bat Google.Chrome & set isShortCut=1 )
			if /I "%%a"=="Firefox" ( call C:\Admin\Scripts\cats-install-winget.bat Mozilla.Firefox & set isShortCut=1 )
			if /I "%%a"=="VLC" ( call C:\Admin\Scripts\cats-install-winget.bat VideoLAN.VLC & set isShortCut=1 )
			if /I "%%a"=="intelDASA" ( call C:\Admin\Scripts\cats-install-winget.bat Intel.IntelDriverAndSupportAssistant & set isShortCut=1 )
			if /I "%%a"=="gDrive" ( call C:\Admin\Scripts\cats-install-winget.bat Google.GoogleDrive & set isShortCut=1 )
			if /I "%%a"=="qGIS" ( call C:\Admin\Scripts\cats-install-winget.bat OSGeo.QGIS_LTR & set isShortCut=1 )
			if /I "%%a"=="WireGuard" ( call C:\Admin\Scripts\cats-install-winget.bat WireGuard.WireGuard & set isShortCut=1 )
			if /I "%%a"=="WindowsApp" ( call C:\Admin\Scripts\cats-install-winget.bat Microsoft.WindowsApp & set isShortCut=1 )
			if /I "%%a"=="GWSMO" ( 
				if exist "C:\Admin\Scripts\cats-recipes\Google.GWSMO.bat" ( 
					call "C:\Admin\Scripts\cats-recipes\Google.GWSMO.bat" install
				)
				set isShortCut=1 
			)
			if /I "%%a"=="Acrobat" ( 
				if exist "C:\Admin\Scripts\cats-recipes\Adobe.Acrobat.Reader.bat" ( 
					call "C:\Admin\Scripts\cats-recipes\Adobe.Acrobat.Reader.bat" install 
				)
				set isShortCut=1 
			)
			
			if !isShortCut! EQU 0 (
				echo [33mWARNING   : Package %%a not found as copycat recipe, trying to pass directly to winget [0m
				call C:\Admin\Scripts\cats-install-winget.bat %%a
			)
		)
	)
)

echo [92mDONE     [96m : CopyCat Install[0m
exit /b 0
