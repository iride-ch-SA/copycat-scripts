@echo off
setlocal

rem  CATS_ROOT is where cats is installed, see cats-shadow.bat
rem
rem  The calls to set-user-password.ps1 carry "; exit $LASTEXITCODE": without that tail
rem  powershell -command flattens every non zero code to 1, and that helper answers 3
rem  for a refusal of its own - PowerShell transcription is enabled by policy, so a
rem  generated password shown on screen would be written to the transcript file. Read
rem  as 1 that refusal is indistinguishable from any other failure, and the operator is
rem  told the password could not be set without being told what to change.
if not defined CATS_ROOT set "CATS_ROOT=C:\Admin\Scripts"

if /I "%~1"=="create" (
	if "%~2"=="" (
		echo [31mERROR     : You must specify a username as second parameter [0m
		exit /b 1
	)

	rem With no password given the option keywords slide into the password
	rem slot, so the arguments are normalised and the recipe is called again
	if "%~3"=="" (
		call "%~f0" create "%~2" ask
		exit /b
	)
	if /I "%~3"=="Administrators" (
		call "%~f0" create "%~2" ask Administrators "%~4"
		exit /b
	)
	if /I "%~3"=="no-rdp" (
		call "%~f0" create "%~2" ask no-rdp "%~4"
		exit /b
	)
	if /I "%~3"=="hide" (
		call "%~f0" create "%~2" ask "%~4" hide
		exit /b
	)
	rem hide is an option of its own and can follow any form, so it is moved
	rem to the slot the recipe reads it from - the fifth - whatever slot it
	rem was typed in. Without this cats create User mario ask hide and
	rem cats create User mario no-rdp hide left the keyword where nothing
	rem looks for it, and the account was created and left visible
	if /I "%~4"=="hide" (
		call "%~f0" create "%~2" "%~3" "" hide
		exit /b
	)

	rem cats create User creates a LOCAL account, and only that: it does not
	rem create an account in a domain nor in a tenant, so a name that does not
	rem suit a local account is refused here, before any of the three paths
	rem runs. Without this guard New-LocalUser took an UPN as it came - @ is
	rem not among the characters the SAM database forbids - and a local
	rem homonym of the cloud account was created, then duly added to Users
	rem and to Remote Desktop Users, with no error anywhere.
	rem The name travels in the environment: it is quoted once, by nobody,
	rem and a quote or a space in it cannot reach the PowerShell parser.
	set "CATS_MEMBER=%~2"
	powershell -noprofile -executionpolicy bypass -command "& %CATS_ROOT%\ps\test-local-name.ps1 -username $env:CATS_MEMBER; exit $LASTEXITCODE"
	if errorlevel 1 (
		echo [94mUSAGE     : cats create User creates a local account. An account that lives in a domain or in a tenant is not created here: use cats prepare Userlogin and cats prepare WireGuard on the account as it is [0m
		exit /b 2
	)

	if /I "%~3"=="ask" (
		echo [36mRECIPE    : Create the user, the password is typed without being shown [0m
		powershell -noprofile -executionpolicy bypass -command "& %CATS_ROOT%\ps\set-user-password.ps1 '%~2' ask -create; exit $LASTEXITCODE"
		if errorlevel 3 (
			echo [33mWARNING   : the password was not set: PowerShell transcription is enabled by policy, see above [0m
			exit /b 3
		)
		if errorlevel 1 exit /b 1
	) else (
		if /I "%~3"=="random" (
			echo [36mRECIPE    : Create the user with a generated password [0m
			powershell -noprofile -executionpolicy bypass -command "& %CATS_ROOT%\ps\set-user-password.ps1 '%~2' random -create; exit $LASTEXITCODE"
			if errorlevel 3 (
				echo [33mWARNING   : the password was not set: PowerShell transcription is enabled by policy, see above [0m
				exit /b 3
			)
			if errorlevel 1 exit /b 1
		) else (
			echo [33mWARNING   : The password is on the command line and any process listing can read it. Use ask or random instead [0m
			echo [36mRECIPE    : Create the user active and without expiration date [0m
			cmd /c net user /add "%~2" "%~3" /expires:never /active:yes
		)
	)

	rem Every account has to be a member of Users: that is the group the
	rem sign-in screen and netplwiz enumerate, and New-LocalUser - unlike
	rem net user /add - leaves the new account in no group at all. An
	rem account created with ask or random was therefore reachable over
	rem RDP and not listed at the console. The membership is asked for on
	rem every path, literal password included: the helper reads the group
	rem back, and an account that is already a member is a success.
	rem The name travels in the environment: it is quoted once, by nobody,
	rem and a quote or a space in it cannot reach the PowerShell parser.
	rem A helper called with -command hands back 1 for any failure it
	rem meets, whatever code it exited with, so the code is re-raised.
	rem CATS_MEMBER already holds the name, set before the guard above.
	echo [36mRECIPE    : Adding user to the Users group [0m
	powershell -noprofile -executionpolicy bypass -command "& %CATS_ROOT%\ps\set-localgroup-member.ps1 -username $env:CATS_MEMBER -sid S-1-5-32-545; exit $LASTEXITCODE"
	if errorlevel 2 exit /b 2

	rem The built-in groups are named by SID and never by name: on a
	rem localised Windows they are translated - Operatori di
	rem configurazione di rete was measured on an Italian machine - so
	rem the hardcoded net localgroup administrators used here before
	rem fails wherever that group is not called that
	if /I "%~4"=="Administrators" (
		echo [36mRECIPE    : Adding user to the Administrators group [0m
		powershell -noprofile -executionpolicy bypass -command "& %CATS_ROOT%\ps\set-localgroup-member.ps1 -username $env:CATS_MEMBER -sid S-1-5-32-544; exit $LASTEXITCODE"
		if errorlevel 2 exit /b 2
	) else (
		if /I not "%~4"=="no-rdp" (
			echo [36mRECIPE    : Adding non-administrative user to the Remote Desktop Users group [0m
			powershell -noprofile -executionpolicy bypass -command "& %CATS_ROOT%\ps\set-localgroup-member.ps1 -username $env:CATS_MEMBER -sid S-1-5-32-555; exit $LASTEXITCODE"
			if errorlevel 2 exit /b 2
		)
	)

	rem hide is applied here, after the groups and on every form of the
	rem command: cats create User mario hide normalises to create mario ask ""
	rem hide and takes the non-administrative branch, and it has to hide the
	rem account just as cats create User mario Administrators hide does.
	rem A hide that fails is reported: the account exists either way, so the
	rem operator has to know it is still listed.
	if /I "%~5"=="hide" (
		echo [36mRECIPE    : Hiding user from login screen [0m
		call "%~f0" prepare "%~2" hide
		if errorlevel 1 (
			echo [33mWARNING   : the account was created but it is still on the sign-in screen [0m
			exit /b 2
		)
	)
	exit /b 0
)

if /I "%~1"=="clean" (
	if "%~2"=="" (
		echo [31mERROR     : You must specify a username as second parameter [0m
		exit /b 1
	)

	rem With no third parameter the password is generated
	if "%~3"=="" (
		call "%~f0" clean "%~2" random
		exit /b
	)

	if /I "%~3"=="ask" (
		echo [36mRECIPE    : Password typed without being shown, account enabled and without expiration date [0m
		powershell -noprofile -executionpolicy bypass -command "& %CATS_ROOT%\ps\set-user-password.ps1 '%~2' ask; exit $LASTEXITCODE"
		if errorlevel 3 (
			echo [33mWARNING   : the password was not set: PowerShell transcription is enabled by policy, see above [0m
			exit /b 3
		)
		if errorlevel 1 exit /b 1
		exit /b 0
	)

	if /I "%~3"=="random" (
		echo [36mRECIPE    : New random password, account enabled and without expiration date [0m
		powershell -noprofile -executionpolicy bypass -command "& %CATS_ROOT%\ps\set-user-password.ps1 '%~2' random; exit $LASTEXITCODE"
		if errorlevel 3 (
			echo [33mWARNING   : the password was not set: PowerShell transcription is enabled by policy, see above [0m
			exit /b 3
		)
		if errorlevel 1 exit /b 1
		exit /b 0
	)

	echo [31mERROR     : The third parameter must be ask or random [0m
	exit /b 1
)

if /I "%~1"=="prepare" (
	if "%~2"=="" (
		echo [31mERROR     : You must specify a username as second parameter [0m
		exit /b 1
	)

	if /I "%~3"=="show" (
		call :visibility "%~2" show
		if errorlevel 1 exit /b 2
		exit /b 0
	)

	if /I "%~3"=="hide" (
		call :visibility "%~2" hide
		if errorlevel 1 exit /b 2
		exit /b 0
	)

	echo [31mERROR     : You must specify show or hide as third parameter [0m
	exit /b 1
)

exit /b 2

rem ============================================================
rem  hide and show write, and remove, the value an account has
rem  under Winlogon SpecialAccounts UserList, which is what keeps
rem  it off the sign-in screen.
rem  The NAME of that value is not the name that gets typed: it
rem  has to be the one the account signs in under, the same rule
rem  that governs C:\Admin\Others\<name>.bat. Getting it wrong
rem  gives no error at all - reg add writes a value under any
rem  name and returns 0 - and the account stays visible while
rem  the command reports success.
rem  That key lists LOCAL accounts, so ps\resolve-logon-name.ps1
rem  is asked with -local: it measures the name on the machine and
rem  refuses a domain or an Entra account outright, instead of
rem  deriving a plausible name and writing it down for nobody.
rem  for /f keeps standard output and leaves standard error on the
rem  console, where the operator reads what the helper measured.
rem ============================================================

:visibility
set "UV_ACCOUNT=%~1"
set "UV_ACTION=%~2"
set "UV_NAME="
for /f "usebackq delims=" %%n in (`powershell -noprofile -executionpolicy bypass -command "& %CATS_ROOT%\ps\resolve-logon-name.ps1 -username $env:UV_ACCOUNT -local; exit $LASTEXITCODE"`) do set "UV_NAME=%%n"

if not defined UV_NAME (
	echo [31mERROR     : the name %UV_ACCOUNT% signs in under could not be read on this machine, nothing was written [0m
	echo [94mUSAGE     : hide and show act on the sign-in screen, which lists local accounts only [0m
	exit /b 1
)

if /I "%UV_ACTION%"=="show" (
	echo [36mRECIPE    : Showing %UV_NAME% on the sign-in screen [0m
	reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" /v "%UV_NAME%" /f
	exit /b 0
)

echo [36mRECIPE    : Hiding %UV_NAME% from the sign-in screen [0m
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" /t REG_DWORD /f /d 0 /v "%UV_NAME%"
exit /b 0
