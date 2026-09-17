@echo off
setlocal

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
rem  The join itself is not done here - that is Settings, or a
rem  provisioning package. This runs before it.
rem  Two steps, in this order:
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
rem     it was handed.
rem  Exit codes: 0 both steps done, 1 the sign-in screen is
rem  ready but itadmin is not an account of this machine so
rem  nothing was hidden, 2 a step failed.
rem ============================================================

set tenant365_account=itadmin
set tenant365_user_recipe=C:\Admin\Scripts\cats-recipes\User.bat

if /I "%~1"=="deploy" (
	call :deploy "%~2"
	rem if errorlevel is greater-or-equal, so the codes are asked from
	rem the highest down. ERRORLEVEL itself cannot be read here: it
	rem would be expanded when this block is read, before the call
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
call C:\Admin\Scripts\set-registry.bat aad-users show
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
exit /b 0
