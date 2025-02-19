@echo off
:: Check if a parameter (file path) has been passed
if "%~1"=="" (
	echo Error: You must specify the file path.
	echo Usage: save_or_verify_hash.bat "C:\path\to\file.txt"
	exit /b 1
)

:: Set the file path from the parameter
set "file=%~1"

:: Extract the directory and filename without extension
for %%f in ("%file%") do (
	set "filename=%%~nf"
	set "filepath=%%~dpf"
)

:: Generate the output .hash file path
set "outputfile=%filepath%%filename%.hash"

:: Calculate the SHA256 hash of the file
echo Calculating SHA256 hash for %file%...
for /f "tokens=* usebackq" %%a in (`certutil -hashfile "%file%" sha256 ^| findstr /v "CertUtil:"`) do set "hash_calculated=%%a"

:: Remove spaces and carriage return from calculated hash
set "hash_calculated=%hash_calculated: =%"
set "hash_calculated=%hash_calculated:`r=%"

:: Check if the .hash file exists
if not exist "%outputfile%" (
	echo No .hash file found. Creating a new .hash file...
	echo %hash_calculated% > "%outputfile%"
	echo Hash saved to %outputfile%
) else (
	echo .hash file found: %outputfile%
	echo Verifying hash...

	:: Read the first valid non-empty line from the .hash file
	set "hash_saved="
	for /f "usebackq delims=" %%b in ("%outputfile%") do (
		set "hash_saved=%%b"
		goto compare
	)

	:compare
	:: Remove spaces and carriage return from saved hash
	set "hash_saved=%hash_saved: =%"
	set "hash_saved=%hash_saved:`r=%"

	:: Compare the calculated hash with the saved hash
	if "%hash_calculated%"=="%hash_saved%" (
		echo The hash matches. The file is intact.
	) else (
		echo The hash does NOT match. The file may have been modified!
		echo Calculated hash: [%hash_calculated%]
		echo Saved hash: [%hash_saved%]
	)
)

pause
