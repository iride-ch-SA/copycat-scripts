@echo off

if "%~1"=="install" (
	call C:\Admin\Scripts\cats-install-winget.bat Google.Chrome
	call C:\Admin\Scripts\cats-install-winget.bat Mozilla.Firefox
	call C:\Admin\Scripts\cats-install-winget.bat VideoLAN.VLC
	if exist C:\Admin\Scripts\cats-recipes\Adobe.Acrobat.Reader.bat ( 
		call C:\Admin\Scripts\cats-recipes\Adobe.Acrobat.Reader.bat install
	)
	exit /b 0
)

exit /b 2