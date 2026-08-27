@echo off
setlocal enabledelayedexpansion

set _wsearch=winget search %~1 --accept-source-agreements
for /f "tokens=* delims=(=" %%s in ('!_wsearch! ^|find /I /c " %~1 "') do (
	if %%s EQU 1 (
		set _wlist=winget list --id %~1 --accept-source-agreements
		for /f "tokens=* delims=(=" %%f in ('!_wlist! ^|find /I /c " %~1 "') do (
			if %%f EQU 0 (
				echo [36mWINGET    : Installing %~1 [0m
				winget install %~1 %~2 %~3 --accept-package-agreements --accept-source-agreements
				exit /b 0
			) else (
				echo [36mWINGET    : Upgrading %~1 [0m
				winget upgrade %~1 --accept-package-agreements --accept-source-agreements
				exit /b 1
			)
		)
	) else (
		if %%s GTR 1 (
			echo [31mERROR     : Winget has more than one package for %~1. [0m
			echo [36mWINGET    : This is what winget knows about %~1 [0m
			winget search %~1 --accept-source-agreements
			echo [36mWINGET    : Call cats install again with one exact Id from the Id column [0m
			exit /b 2
		) else (
			echo [31mERROR     : Package %~1 cannot be found in winget. [0m
			echo [36mWINGET    : This is what winget knows about %~1 [0m
			winget search %~1 --accept-source-agreements
			exit /b 2
		)
	)
)

exit /b 3
