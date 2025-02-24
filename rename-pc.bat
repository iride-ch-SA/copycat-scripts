@echo off
setlocal enabledelayedexpansion

set "chars=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
set "randomName="
for /l %%i in (1,1,9) do (
	set /a "randIndex=!random! %% 36"
	for %%j in (!randIndex!) do set "randomName=!randomName!!chars:~%%j,1!"
)

set "newName=PC-%randomName%"
powershell -noprofile -executionpolicy bypass -command "Rename-Computer -NewName "!newName!" -Restart"
