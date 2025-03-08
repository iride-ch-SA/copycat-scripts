@echo off
setlocal enabledelayedexpansion

echo [95mSTARTING [96m : CopyCat Install[0m

for %%a in (%*) do (
	if /I "%%a"=="Adobe.Acrobat.Reader" (
		if "%PROCESSOR_ARCHITECTURE%" == "AMD64" (
			winget list --id Adobe.Acrobat.Reader.64-bit | findstr /I "Adobe.Acrobat.Reader.64-bit" > nul
			if %errorlevel% neq 0 (
				echo [36mWINGET    : Installing Adobe Acrobat Reader 64bit [0m
				winget install --id Adobe.Acrobat.Reader.64-bit --accept-package-agreements --accept-source-agreements
			) else (
				echo [36mWINGET    : Upgrading Adobe Acrobat Reader 64bit [0m
				winget upgrade --id Adobe.Acrobat.Reader.64-bit
			)
		) else (
			winget list --id Adobe.Acrobat.Reader.32-bit | findstr /I "Adobe.Acrobat.Reader.32-bit" > nul
			if %errorlevel% neq 0 (
				echo [36mWINGET    : Installing Adobe Acrobat Reader 32bit [0m
				winget install --id Adobe.Acrobat.Reader.32-bit --accept-package-agreements --accept-source-agreements
			) else (
				echo [36mWINGET    : Upgrading Adobe Acrobat Reader 64bit [0m
				winget upgrade --id Adobe.Acrobat.Reader.32-bit
			)
		)
	) else (
		echo [33mWARNING   : Package %%a not found as copycat recipe, trying to pass directly to winget [0m
		winget search %%a | findstr /I "%%a" > nul
		if !errorlevel! neq 0 (
			echo [31mERROR     : Package %%a cannot be found in winget. [0m
		) else (
			winget list --id Adobe.Acrobat.Reader.64-bit | findstr /I "Adobe.Acrobat.Reader.64-bit" > nul
			if !errorlevel! neq 0 (
				echo [36mWINGET    : Installing %%a [0m
				winget install %%a --accept-package-agreements --accept-source-agreements
			) else (
				echo [36mWINGET    : Upgrading %%a [0m
				winget upgrade %%a
			)
		)
	)
)
echo [92mDONE     [96m : CopyCat Install[0m
