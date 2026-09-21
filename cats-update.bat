@echo off
setlocal enabledelayedexpansion

echo [95mSTARTING [96m : CopyCat Update[0m

for %%a in (%*) do (
	if exist C:\Admin\Scripts\cats-recipes\%%a.bat ( 
		call "C:\Admin\Scripts\cats-recipes\%%a.bat" update %2 %3 %4 %5 %6 %7 %8 %9
	) else (
		if exist C:\Admin\Scripts\cats-recipes\Cats.%%a.bat (
			call "C:\Admin\Scripts\cats-recipes\Cats.%%a.bat" update %2 %3 %4 %5 %6 %7 %8 %9
		)
	)
	
	if /I "%%a"=="Windows" (
		winget upgrade --all --accept-package-agreements --accept-source-agreements
		powershell -Command "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force"

		rem One pass of Windows Update, and no -AutoReboot: the restart is
		rem ordered by cats-resume.bat, which writes down what is still to
		rem do before it happens. Windows Update only shows what is left
		rem after a restart, so one pass never means "up to date" - the
		rem helper answers 1 for "come back after a restart" and the chain
		rem runs this step again until a pass answers 0.
		rem The exit tail is what carries that 1 past powershell -command
		powershell -noprofile -executionpolicy bypass -command "& C:\Admin\Scripts\ps\windows-update.ps1; exit $LASTEXITCODE"
		if errorlevel 2 (
			echo [31mERROR     : Windows Update could not be driven from here, the reason is in the lines above [0m
		) else (
			if errorlevel 1 (
				call C:\Admin\Scripts\cats-resume.bat request again
			)
		)
	)
)

echo [92mDONE     [96m : CopyCat Update[0m
exit /b 0
