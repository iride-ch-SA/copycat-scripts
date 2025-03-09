@echo off

if "%~1"=="install" (
	if "%PROCESSOR_ARCHITECTURE%" == "AMD64" (
		call C:\Admin\Scripts\cats-install-winget.bat Adobe.Acrobat.Reader.64-bit
		exit /b 0
	) else (
		call C:\Admin\Scripts\cats-install-winget.bat Adobe.Acrobat.Reader.32-bit
		exit /b 0
	)
)
exit /b 2