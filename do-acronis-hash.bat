@echo off
setlocal enabledelayedexpansion

for %%F in ("A:\*.tib") do (
	set "tibfile=%%~nxF"
	goto :found
)
exit

:found
C:\Admin\Scripts\hasher.bat A:\%tibfile%