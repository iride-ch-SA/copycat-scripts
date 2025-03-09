@echo off
	call C:\Admin\Scripts\cats-install-winget.bat Google.Chrome
	call C:\Admin\Scripts\cats-install-winget.bat Mozilla.Firefox
	call C:\Admin\Scripts\cats-install-winget.bat VideoLAN.VLC
	if exist C:\Admin\Scripts\cats-recipes\Adobe.Acrobat.Reader.bat ( 
		call C:\Admin\Scripts\cats-recipes\Adobe.Acrobat.Reader.bat 
	)
exit /b 0