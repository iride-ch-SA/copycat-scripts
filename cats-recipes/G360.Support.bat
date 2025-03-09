@echo off
	echo [36mRECIPE    : Downloading G360 Support Software [0m
	powershell -command "(new-object System.Net.WebClient).DownloadFile('https://storage.googleapis.com/01931185-232c-77a5-8e67-8751490ebf3e/SupportoIT/supportoit.exe','C:\Admin\Apps\supportoit.exe')"
	
	echo [36mRECIPE    : Creating Desktop link for all users [0m
	if not exist "C:\Users\Public\Desktop\Supporto IT" (
		Powershell -command "New-Item -ItemType SymbolicLink -Path 'C:\Users\Public\Desktop' -Name 'Supporto IT' -Value 'C:\Admin\Apps\supportoit.exe'"
	)
exit /b 0