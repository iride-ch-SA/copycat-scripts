@echo off
setlocal enabledelayedexpansion

rem  CATS_HOME is the copy this run reads its .bat files from, see cats-shadow.bat
rem  CATS_ROOT is where cats is installed, see cats-shadow.bat
if not defined CATS_ROOT set "CATS_ROOT=C:\Admin\Scripts"
if not defined CATS_HOME set "CATS_HOME=%CATS_ROOT%"

echo [95mSTARTING [96m : CopyCat Clean[0m

for %%a in (%*) do (
	if exist "%CATS_HOME%\cats-recipes\%%a.bat" ( 
		call "%CATS_HOME%\cats-recipes\%%a.bat" clean %2 %3 %4 %5 %6 %7 %8 %9
	) else (
		if exist "%CATS_HOME%\cats-recipes\Cats.%%a.bat" (
			call "%CATS_HOME%\cats-recipes\Cats.%%a.bat" clean %2 %3 %4 %5 %6 %7 %8 %9
		)
	)
	
	rem  Two steps, in this order: cleanmgr takes the files off the
	rem  volume, the retrim tells the layer underneath that the blocks
	rem  they used are free again. Without the second one a virtual
	rem  machine frees space inside the guest and none at all in the
	rem  vmdk or the vhdx, which is the space someone is paying for.
	rem  The retrim is done on every volume that can take it, not on
	rem  C: alone. cats clean disks list removes nothing: it says
	rem  which volumes the retrim would take.
	if /I "%%a"=="disks" (
		if /I "%~2"=="list" (
			echo [36mSHORTCUT  : Which volumes a retrim would take [0m
			powershell -noprofile -executionpolicy bypass -command "& %CATS_ROOT%\ps\retrim-volumes.ps1 -List; exit $LASTEXITCODE"
		) else (
			echo [36mSHORTCUT  : Do a Cleanmgr with sagerun:1 [0m
			cmd /c cleanmgr /sagerun:1
			echo [36mSHORTCUT  : Give the freed space back, on every volume that takes a retrim [0m
			powershell -noprofile -executionpolicy bypass -command "& %CATS_ROOT%\ps\retrim-volumes.ps1; exit $LASTEXITCODE"
			if errorlevel 1 (
				echo [33mWARNING   : no volume was retrimmed, the lines above say why [0m
			)
		)
	)
	
	rem  CATS_HOME is the copy under the temporary folder this very
	rem  run reads its .bat files from, and it is handed over so that
	rem  the sweep does not delete the code that is running
	if /I "%%a"=="tmp" (
		if /I "%~2"=="list" (
			echo [36mSHORTCUT  : What a clean of the logs and the temporary files would take off this machine [0m
			powershell -noprofile -executionpolicy bypass -command "& %CATS_ROOT%\ps\clean-temp.ps1 -List -KeepPath '%CATS_HOME%'; exit $LASTEXITCODE"
		) else (
			echo [36mSHORTCUT  : Clearing the logs and the temporary files of this machine [0m
			powershell -noprofile -executionpolicy bypass -command "& %CATS_ROOT%\ps\clean-temp.ps1 -KeepPath '%CATS_HOME%'; exit $LASTEXITCODE"
		)
		if errorlevel 2 (
			echo [31mERROR     : nothing was cleared, the lines above say why [0m
		)
	)
	
	if /I "%%a"=="sfc" (
		echo [36mSHORTCUT  : Do an sfc /scannow [0m
		sfc /scannow
	)
	
	if /I "%%a"=="dism-online" (
		echo [36mSHORTCUT  : Restore Windows Image [0m
		DISM /Online /Cleanup-Image /AnalyzeComponentStore
		DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase
		DISM /Online /Cleanup-Image /RestoreHealth
	)
	
	if /I "%%a"=="network" (
		echo [36mSHORTCUT  : Fully reset Network [0m
		ipconfig /release & ipconfig /renew
		ipconfig /flushdns
		timeout /t 5 /nobreak >nul
		powershell -noprofile -executionpolicy bypass -command "Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private"
	)
	
	rem  The restart this needs is NOT ordered here: cats-resume.bat is
	rem  told that one is needed and the chain this step belongs to -
	rem  cats clean Machine is one - orders it once it has written down
	rem  what is left to do. That is the convention every step of this
	rem  repository follows, see cats-recipes\Drivers.bat. Typed by hand,
	rem  outside a chain, nothing restarts and the machine is left for
	rem  the operator to restart.
	if /I "%%a"=="win-updates" (
		echo [36mSHORTCUT  : Clean Windows Updates folder [0m
		REM **** Clean Windows updates
		net stop wuauserv
		net stop bits
		del /f /s /q %windir%\SoftwareDistribution\*
		net start wuauserv
		net start bits
		echo [33mWARNING   : the Windows Update folder is emptied, and a restart is needed before it is built again [0m
		echo [94mUSAGE     : restart this machine before it is used, or leave it to the chain this step is part of [0m
		call "%CATS_HOME%\cats-resume.bat" request
	)
	
	if /I "%%a"=="itadmin" (
		if /I not "%~1"=="User" (
			echo [36mSHORTCUT  : New random password for the itadmin account [0m
			if exist "%CATS_HOME%\cats-recipes\User.bat" (
				call "%CATS_HOME%\cats-recipes\User.bat" clean itadmin "%~2"
			)
		)
	)
)

echo [92mDONE     [96m : CopyCat Clean[0m
exit /b 0
