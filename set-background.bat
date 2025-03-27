@echo off
echo [96m----- Set Background Script[0m [92mSTARTED[0m [96m-----[0m 

if "%~1"=="get" (
	IF NOT EXIST "C:\Admin\Others\background.jpg" (
		if "%~2"=="" (
			echo [36mDownloading default cats background[0m
			powershell -command "(new-object System.Net.WebClient).DownloadFile('https://storage.googleapis.com/01931185-232c-77a5-8e67-8751490ebf3e/CopyCats/Admin/Others/backgrounds/background.jpg','C:\Admin\Others\background.jpg')"
		) ELSE (
			echo [36mDownloading %~2 cats background[0m
			powershell -command "(new-object System.Net.WebClient).DownloadFile('https://storage.googleapis.com/01931185-232c-77a5-8e67-8751490ebf3e/CopyCats/Admin/Others/backgrounds/%~2.jpg','C:\Admin\Others\background.jpg')"
		)
	) ELSE (
		echo [33mWARNING: C:\Admin\Others\background.jpg already exist, nothing was done. [0m
	)
)

if "%~1"=="remove" (
	IF EXIST "C:\Admin\Others\background.jpg" (
		del C:\Admin\Others\background.jpg
	)
)


IF EXIST "C:\Admin\Scripts\config\%username%.bgi" (
	echo [36mUsing a profile specific for user %username% found in C:\Admin\Scripts\config\%username%.bgi[0m
	C:\Admin\Apps\Bginfo.exe C:\Admin\Scripts\config\%username%.bgi /timer:0 /silent /accepteula
) ELSE IF EXIST "C:\Admin\Others\%username%.bgi" (
	echo [36mUsing a profile specific for user %username% found in C:\Admin\Others\%username%.bgi[0m
	C:\Admin\Apps\Bginfo.exe C:\Admin\Others\%username%.bgi /timer:0 /silent /accepteula
) ELSE IF EXIST "C:\Admin\Others\background.bgi" (
	echo [36mUsing a profile found in C:\Admin\Others\background.bgi[0m
	C:\Admin\Apps\Bginfo.exe C:\Admin\Others\background.bgi /timer:0 /silent /accepteula
) ELSE IF EXIST "C:\Admin\Others\background.jpg" (
	echo [36mUsing the image found in C:\Admin\Others\background.jpg[0m
	C:\Admin\Apps\Bginfo.exe C:\Admin\Scripts\config\background.bgi /timer:0 /silent /accepteula
) ELSE IF EXIST "C:\Admin\Scripts\config\solid-color.bgi" (
	echo [36mUsing solid color for background, no specific profile or image found[0m
	C:\Admin\Apps\Bginfo.exe C:\Admin\Scripts\config\solid-color.bgi /timer:0 /silent /accepteula
)

echo [96m----- Set Background Script[0m [95mENDED[0m [96m-----[0m 
