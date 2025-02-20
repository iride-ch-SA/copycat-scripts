@echo off
set userlogin_file_path="C:\Admin\Scripts\userlogin.bat"

REM Create userlogin script file if doesn't exist
if not exist %userlogin_file_path% (
	set userlogin_script_title=REM Userlogin Script
	
	@echo on
	echo %userlogin_script_title% > %userlogin_file_path%
	@echo off
)

REM Create task to run it at each user login
set taskName="Run userlogin script"
schtasks /create /tn %taskName% /tr %userlogin_file_path% /sc onlogon /f

@echo on
echo "Rember to change to Group Users the scheduled task for userlogin.bat"