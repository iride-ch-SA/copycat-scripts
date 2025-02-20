@echo off
IF EXIST "C:\Admin\Scripts\config\%username%.bgi" (
	C:\Admin\Apps\Bginfo.exe C:\Admin\Scripts\config\%username%.bgi /timer:0 /silent
) else (
	IF EXIST "C:\Admin\Others\background.jpg" (
		C:\Admin\Apps\Bginfo.exe C:\Admin\Scripts\config\background.bgi /timer:0 /silent
	) else (
		IF EXIST "C:\Admin\Scripts\config\solid-color.bgi" (
			C:\Admin\Apps\Bginfo.exe C:\Admin\Scripts\config\solid-color.bgi /timer:0 /silent
		)
	)
)