@echo off
setlocal enabledelayedexpansion

echo [96m----- Cats Install Script[0m [92mSTARTED[0m [96m-----[0m 

for %%a in (%*) do (
	if /I "%%a"=="Adobe.Acrobat.Reader" (
		if "%PROCESSOR_ARCHITECTURE%" == "AMD64" (
			echo [36mInstalling Adobe Acrobat Reader 64bit using winget[0m
			winget install Adobe.Acrobat.Reader.64-bit --accept-package-agreements --accept-source-agreements
		) else (
			echo [36mInstalling Adobe Acrobat Reader 32bit using winget[0m
			winget install Adobe.Acrobat.Reader.32-bit --accept-package-agreements --accept-source-agreements
		)
	)
)

echo [96m----- Cats Install Script[0m [95mENDED[0m [96m-----[0m 
