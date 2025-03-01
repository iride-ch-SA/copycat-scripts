@echo off
setlocal enabledelayedexpansion

echo [96m----- Cats Prepare Script[0m [92mSTARTED[0m [96m-----[0m 

for %%a in (%*) do (
	if /I "%%a"=="scripts" (
		echo [36mUpdate Scripts Folder[0m 
		git --git-dir="C:\Admin\Scripts\.git" --work-tree="C:\Admin\Scripts" pull 
		call C:\Admin\Scripts\set-path.bat
	)

	if /I "%%a"=="admin-folders" (
		echo [36mPreparing/Upgrading C:\Admin folder structure[0m
		if not exist "C:\Admin" ( mkdir C:\Admin )
		if exist "C:\Admin" ( echo [32mOK:[0m C:\Admin ) else ( echo [31mERROR: C:\Admin wasn't created [0m )
		if not exist "C:\Admin\Apps" ( mkdir C:\Admin\Apps )
		if exist "C:\Admin\Apps" ( echo [32mOK:[0m C:\Admin\Apps ) else ( echo [31mERROR: C:\Admin\Apps wasn't created [0m )
		if not exist "C:\Admin\Drivers" ( mkdir C:\Admin\Drivers )
		if exist "C:\Admin\Drivers" ( echo [32mOK:[0m C:\Admin\Drivers ) else ( echo [31mERROR: C:\Admin\Drivers wasn't created [0m )
		if not exist "C:\Admin\Installers" ( mkdir C:\Admin\Installers )
		if exist "C:\Admin\Installers" ( echo [32mOK:[0m C:\Admin\Installers ) else ( echo [31mERROR: C:\Admin\Installers wasn't created [0m )
		if not exist "C:\Admin\Others" ( mkdir C:\Admin\Others )
		if exist "C:\Admin\Others" ( echo [32mOK:[0m C:\Admin\Others ) else ( echo [31mERROR: C:\Admin\Others wasn't created [0m )
	)

	if /I "%%a"=="utils" (
		echo [36mInstall Utilities[0m 

		echo [36m Install BGInfo from install-destination-softwares[0m 
		call C:\Admin\Scripts\install-destination-softwares.bat bginfo
		echo [36m Install Template from install-destination-softwares[0m
		call C:\Admin\Scripts\install-destination-softwares.bat template
		echo [36m Install Base from install-destination-softwares[0m
		call C:\Admin\Scripts\install-destination-softwares.bat base
		echo [36m Install Support from install-destination-softwares[0m
		call C:\Admin\Scripts\install-destination-softwares.bat support 

		echo [36m Create a cleanmgr preset :1[0m
		cleanmgr /sageset:1
	)

	if /I "%%a"=="systailoring" (
		echo [36mSet specific system parameters[0m 
		echo [36mDisable Widgets in menu bar for all users[0m 
		call C:\Admin\Scripts\set-registry.bat news-and-interests disable
		echo [36mReset Power Settings to an always-on status[0m 
		call C:\Admin\Scripts\reset-power-settings.bat
	)

	if /I "%%a"=="win-updates" (
		echo [36mInstall Power Shell Windows Updates Tools[0m 
		powershell -command "Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force"
		powershell -command "Install-Module PSWindowsUpdate -Force"
		powershell -command "Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted"
	)

	if /I "%%a"=="deploy-azure" (
		echo [36mConfigure System for Azure joining[0m 
		echo [36m Show AAD Users on Login Screen[0m
		call C:\Admin\Scripts\set-registry.bat aad-users show
		echo [36m Hide itadmin from Login Screen[0m
		call C:\Admin\Scripts\set-registry.bat local-user hide itadmin
	)
)

echo [96m----- Cats Prepare Script[0m [95mENDED[0m [96m-----[0m 
