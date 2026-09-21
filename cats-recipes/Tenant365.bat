@echo off
setlocal

rem  CATS_HOME is the copy this run reads its .bat files from, see cats-shadow.bat
if not defined CATS_HOME set "CATS_HOME=C:\Admin\Scripts"

rem ============================================================
rem  Tenant365
rem  cats deploy Tenant365 gets this machine ready to be joined
rem  to a Microsoft 365 / Entra ID tenant: the sign-in screen
rem  lists the accounts that sign in on it, and the local
rem  administrative account is taken off that list.
rem  It is what cats prepare deploy-azure did until September
rem  2026, and that shortcut no longer exists. The work is here
rem  because an inline block of cats-prepare.bat could not be
rem  told whether it had worked: nothing read the outcome of
rem  what it called, so a machine that refused both settings
rem  finished with the same DONE line as one that took them.
rem  The join itself stays the operator's: the third step only
rem  opens the page of Settings it is done from, and the steps
rem  on screen - tenant account, password, second factor - are
rem  followed by whoever is at the machine.
rem  Three steps, in this order:
rem   - set-registry.bat aad-users show, which enumerates local
rem     and connected users on the sign-in screen. It needs an
rem     elevated prompt, and it is asked first on purpose: it is
rem     the step whose exit code tells whether this prompt can
rem     write under HKLM at all;
rem   - User.bat prepare itadmin hide, which writes the value
rem     that keeps the account off the sign-in screen. Hidden is
rem     not disabled: it still signs in, by typing the name.
rem     That recipe is called rather than set-registry.bat
rem     local-user because it reads the name the account really
rem     signs in under and refuses one that is not on this
rem     machine, instead of writing a value under whatever name
rem     it was handed;
rem   - Settings, opened on Access work or school, which is the
rem     normal way a machine is joined to a tenant. It is asked
rem     last because the sign-in screen is meant to be ready
rem     before the join, and it is skipped on a machine dsregcmd
rem     already reports as joined.
rem  Exit codes: 0 the machine is ready and the join page is up,
rem  or the machine is joined already, 1 the sign-in screen is
rem  ready but itadmin is not an account of this machine so
rem  nothing was hidden and the join page was not opened - the
rem  message asks for a second run, 2 a step failed, 3 both
rem  settings are written but Settings did not come up, so the
rem  join has to be opened by hand.
rem ============================================================

set tenant365_account=itadmin
set tenant365_user_recipe=%CATS_HOME%\cats-recipes\User.bat
rem The Settings page the join is done from, and the process that has to be
rem there afterwards for the page to be considered open
set tenant365_settings_uri=ms-settings:workplace
set tenant365_settings_process=SystemSettings.exe

if /I "%~1"=="deploy" (
	call :deploy "%~2"
	rem if errorlevel is greater-or-equal, so the codes are asked from
	rem the highest down. ERRORLEVEL itself cannot be read here: it
	rem would be expanded when this block is read, before the call
	if errorlevel 3 exit /b 3
	if errorlevel 2 exit /b 2
	if errorlevel 1 exit /b 1
	exit /b 0
)

exit /b 2

:deploy
if not "%~1"=="" (
	echo [33mWARNING   : deploy takes no parameter, so %~1 was ignored [0m
	echo [94mUSAGE     : cats deploy Tenant365 acts on this machine, and the account it hides is %tenant365_account% [0m
)

echo [32mRECIPE    : Listing local and connected accounts on the sign-in screen [0m
rem set-registry.bat starts by deleting a policy value most machines never
rem had, so reg prints "unable to find the specified registry key or value"
rem on the way through: that line is expected and is not the outcome. What
rem is judged is the code the call hands back, which is the one of the last
rem reg command it runs
call "%CATS_HOME%\set-registry.bat" aad-users show
if errorlevel 1 (
	echo [31mERROR     : the sign-in screen was not changed, and nothing else was tried [0m
	echo [94mUSAGE     : these are machine-wide settings under HKLM. Run this from an elevated prompt [0m
	exit /b 2
)

if not exist "%tenant365_user_recipe%" (
	echo [31mERROR     : %tenant365_user_recipe% is missing, so %tenant365_account% cannot be hidden [0m
	echo [94mUSAGE     : it ships with the repository - restore the clone with cats update Scripts reset [0m
	exit /b 2
)

echo [32mRECIPE    : Taking %tenant365_account% off the sign-in screen [0m
call "%tenant365_user_recipe%" prepare %tenant365_account% hide
if errorlevel 1 (
	echo [33mWARNING   : %tenant365_account% is not an account of this machine, so nothing was hidden [0m
	echo [94mUSAGE     : create it with cats create Admin %tenant365_account%, then run cats deploy Tenant365 again [0m
	exit /b 1
)

echo [32mRECIPE    : this machine is ready for the tenant accounts, and %tenant365_account% is hidden [0m

call :open-join
if errorlevel 1 exit /b 3
exit /b 0

:open-join
rem A machine that is already joined does not need the wizard, and opening
rem it there would invite a second join. dsregcmd prints the state as fields
rem and is not localised - the same line is read by ps/wireguard-operators.ps1.
rem If dsregcmd is not there at all, findstr matches nothing and the page is
rem opened, which is the harmless way round
dsregcmd /status 2>nul | findstr /i /r /c:"AzureAdJoined *: *YES" >nul
if not errorlevel 1 (
	echo [32mRECIPE    : this machine is already joined to a tenant, so Settings was not opened [0m
	exit /b 0
)

echo [36mRECIPE    : Opening Settings on Access work or school - the steps on screen are yours [0m
echo [94mUSAGE     : Connect - Add account on Windows 11 - then Join this device to Microsoft Entra ID, then the tenant account [0m
rem Two ways in, tried in this order. explorer.exe hands the URI to the shell
rem already running in this session, which brings Settings up as the signed-in
rem user: it is the way that survives an elevated prompt, where a packaged app
rem is not always allowed to be activated by an elevated process. start is the
rem second try, for a session whose shell is not up. Neither hands back a
rem usable exit code - explorer exits as soon as the shell has taken the URI -
rem so what is judged is whether the Settings process is there afterwards
explorer.exe "%tenant365_settings_uri%"
call :settings-up
if not errorlevel 1 exit /b 0
start "" "%tenant365_settings_uri%"
call :settings-up
if not errorlevel 1 exit /b 0

echo [33mWARNING   : Settings did not come up, so the join was not started - the two settings above are written [0m
echo [94mUSAGE     : open it by hand - Settings, Accounts, Access work or school, Connect [0m
exit /b 1

:settings-up
rem Settings is a packaged app and takes a moment to appear, so the process
rem list is read five times with two seconds in between rather than once after
rem ten: a machine that is quick about it does not pay for one that is slow.
rem This says the app is up, not that it is on the right page - an operator
rem who already had Settings open passes the check on the first read. It is
rem the cheap half of the question, and the useful one: the answer that makes
rem the recipe report a failure is the process not being there at all
for /l %%w in (1,1,5) do (
	timeout /t 2 /nobreak >nul 2>&1
	tasklist /fi "imagename eq %tenant365_settings_process%" 2>nul | find /i "%tenant365_settings_process%" >nul
	if not errorlevel 1 exit /b 0
)
exit /b 1
