@echo off
IF EXIST "C:\Admin\Scripts\config\%username%.bgi" (
	C:\Admin\Apps\BGInfo\Bginfo.exe C:\Admin\Scripts\config\%username%.bgi /timer:0 /silent
)