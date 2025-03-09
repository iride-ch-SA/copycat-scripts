@echo off
	if "%PROCESSOR_ARCHITECTURE%" == "AMD64" (
		call C:\Admin\Scripts\cats-install-winget.bat Adobe.Acrobat.Reader.64-bit
	) else (
		call C:\Admin\Scripts\cats-install-winget.bat Adobe.Acrobat.Reader.32-bit
	)
exit /b 0