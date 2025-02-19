REM **** Update Scripts
git --git-dir="C:\Admin\Scripts\.git" --work-tree="C:\Admin\Scripts" pull

REM **** Create Standard IT Admin folders in C:
mkdir C:\Admin
mkdir C:\Admin\Apps
mkdir C:\Admin\Drivers
mkdir C:\Admin\Installers
mkdir C:\Admin\Others

REM **** Disable Widgets in menu bar (for all users)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /t REG_DWORD /v AllowNewsAndInterests /d "0" /f

REM **** Change Power Settings
powercfg /X monitor-timeout-ac 0
powercfg /X standby-timeout-ac 0
powercfg /X hibernate-timeout-ac 0
powercfg /hibernate off
