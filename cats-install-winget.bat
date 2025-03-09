@echo off

set _wsearch=winget search %~1
for /f "tokens=* delims=(=" %%s in ('%_wsearch% ^|find /I /c " %~1 "') do (
	if %%s EQU 1 (
		set _wlist=winget list --id %~1
		for /f "tokens=* delims=(=" %%f in ('%_wlist% ^|find /I /c " %~1 "') do (
			if %%f EQU 0 (
				echo [36mWINGET    : Installing %~1 [0m
				winget install %~1 %~2 %~3 --accept-package-agreements --accept-source-agreements
				exit /b 0
			) else (
				echo [36mWINGET    : Upgrading %~1 [0m
				winget upgrade %~1
				exit /b 1
			)
		)
	) else (
		if %%s GTR 1 (
			echo [31mERROR     : Winget has more than one package for %~1. [0m
			exit /b 2
		) else (
			echo [31mERROR     : Package %~1 cannot be found in winget. [0m
			exit /b 2
		)
	)
)

exit /b 3
