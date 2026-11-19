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

	rem keep-downloads and clear-downloads can be typed in the slot of the
	rem password or after it, so the first form is turned into the second:
	rem the option goes to the fourth slot, the password keyword - random
	rem when none was typed - to the third, and the recipe is called again.
	rem Anything else after the option is refused, not reordered: two
	rem options together would otherwise be swapped back and forth for ever
	for %%o in (keep-downloads clear-downloads) do if /I "%~3"=="%%o" (
		if "%~4"=="" (
			call "%~f0" clean "%~2" random %%o
			exit /b
		)
		if /I "%~4"=="ask" (
			call "%~f0" clean "%~2" ask %%o
			exit /b
		)
		if /I "%~4"=="random" (
			call "%~f0" clean "%~2" random %%o
			exit /b
		)
		echo [31mERROR     : %%o can be followed by ask or random only [0m
		exit /b 1
	)
	if not "%~4"=="" (
		if /I not "%~4"=="keep-downloads" (
			if /I not "%~4"=="clear-downloads" (
				echo [31mERROR     : The fourth parameter must be keep-downloads or clear-downloads [0m
				exit /b 1
			)
		)
	)

	if /I "%~3"=="ask" (
		echo [36mRECIPE    : Password typed without being shown, account enabled and without expiration date [0m
		powershell -noprofile -executionpolicy bypass -command "& %CATS_ROOT%\ps\set-user-password.ps1 '%~2' ask; exit $LASTEXITCODE"
		if errorlevel 3 (
			echo [33mWARNING   : the password was not set: PowerShell transcription is enabled by policy, see above [0m
			exit /b 3
		)
		if errorlevel 1 exit /b 1
		call :downloads "%~2" "%~4"
		exit /b
	)

	if /I "%~3"=="random" (
		echo [36mRECIPE    : New random password, account enabled and without expiration date [0m
		powershell -noprofile -executionpolicy bypass -command "& %CATS_ROOT%\ps\set-user-password.ps1 '%~2' random; exit $LASTEXITCODE"
		if errorlevel 3 (
			echo [33mWARNING   : the password was not set: PowerShell transcription is enabled by policy, see above [0m
			exit /b 3
		)
		if errorlevel 1 exit /b 1
		call :downloads "%~2" "%~4"
		exit /b
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

	rem rdp and no-rdp give and take the membership of Remote Desktop
	rem Users, the same group cats create User hands out, to an account
	rem that exists already: a local one, a domain one, a tenant 365 one
	rem given by its UPN. See :rdp below
	if /I "%~3"=="rdp" (
		call :rdp "%~2" add
		exit /b
	)

	if /I "%~3"=="no-rdp" (
		call :rdp "%~2" remove
		exit /b
	)

	echo [31mERROR     : You must specify show, hide, rdp or no-rdp as third parameter [0m
	exit /b 1
)

if /I "%~1"=="remove" (
	if "%~2"=="" (
		echo [31mERROR     : You must specify a username as second parameter [0m
		exit /b 1
	)

	rem The third word says what happens to the profile, and without it the
	rem helper asks: delete-profile deletes it, keep-profile keeps the folder
	rem on disk, neither of them asking. The name and the choice travel in the
	rem environment, read by PowerShell when it runs, so a quote or a space in
	rem the name cannot reach its parser. What is removed, and what is not,
	rem depends on where the account lives: see ps\remove-user.ps1
	set "CATS_MEMBER=%~2"
	set "CATS_PROFILE=ask"
	if /I "%~3"=="delete-profile" set "CATS_PROFILE=delete"
	if /I "%~3"=="keep-profile" set "CATS_PROFILE=keep"
	if not "%~3"=="" (
		if /I not "%~3"=="delete-profile" (
			if /I not "%~3"=="keep-profile" (
				echo [31mERROR     : The third parameter must be delete-profile or keep-profile [0m
				exit /b 1
			)
		)
	)
	echo [36mRECIPE    : Removing %~2 from this machine [0m
	powershell -noprofile -executionpolicy bypass -command "& %CATS_ROOT%\ps\remove-user.ps1 -username $env:CATS_MEMBER -ProfileMode $env:CATS_PROFILE; exit $LASTEXITCODE"
	if errorlevel 2 (
		echo [33mWARNING   : the account was removed in part, see above [0m
		exit /b 2
	)
	if errorlevel 1 exit /b 1
	exit /b 0
)

exit /b 2

rem ============================================================
rem  cats clean itadmin - and cats clean User itadmin, which is
rem  the same command - also empties the Downloads folder of
rem  itadmin once the password is set: what was downloaded while
rem  the machine was prepared would otherwise leave with it.
rem  It asks first, y or n; keep-downloads leaves the folder as it
rem  is and clear-downloads empties it, neither of them asking.
rem  The folder is read from HKCU, so it is emptied only when the
rem  command is run BY itadmin: ps\clear-downloads.ps1 compares
rem  %USERNAME% with the account, and run by anybody else it
rem  touches nothing and asks nothing. No other account has its
rem  Downloads folder emptied by cats clean User.
rem  The password is set either way, so a folder that is not
rem  emptied is a warning and an exit code 2, not a failure.
rem ============================================================

:downloads
if /I not "%~1"=="itadmin" (
	if not "%~2"=="" echo [33mWARNING   : %~2 is about the Downloads folder of itadmin, and is ignored for %~1 [0m
	exit /b 0
)
if /I "%~2"=="keep-downloads" (
	echo [36mRECIPE    : The Downloads folder of itadmin is left as it is [0m
	exit /b 0
)
set "UD_MODE=ask"
if /I "%~2"=="clear-downloads" set "UD_MODE=yes"
powershell -noprofile -executionpolicy bypass -command "& %CATS_ROOT%\ps\clear-downloads.ps1 -Account itadmin -Mode %UD_MODE%; exit $LASTEXITCODE"
if errorlevel 2 (
	echo [33mWARNING   : the password is set, the Downloads folder is not empty, see above [0m
	exit /b 2
)
exit /b 0

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

rem ============================================================
rem  rdp and no-rdp put an account that already exists into
rem  Remote Desktop Users, S-1-5-32-555, or take it out. The
rem  account may live anywhere the machine can translate it: a
rem  local name, DOMAIN\user, a tenant 365 account by its UPN -
rem  ps\lib-account.ps1 puts AzureAD\ in front of it - which is
rem  the same cascade cats prepare WireGuard goes through.
rem  The group is named by SID, its name is translated on a
rem  localised Windows, and the helper reads it back either way.
rem  The membership is all this does: Remote Desktop itself is
rem  turned on or off in Settings or by group policy, and no
rem  recipe touches it, so
rem  after rdp the switch is only read, and a machine that has it
rem  off is a warning - the account is a member, nobody connects.
rem  The membership enters the token at the next sign-in.
rem ============================================================

:rdp
set "CATS_MEMBER=%~1"
if /I "%~2"=="remove" (
	echo [36mRECIPE    : Taking %~1 out of the Remote Desktop Users group [0m
	powershell -noprofile -executionpolicy bypass -command "& %CATS_ROOT%\ps\set-localgroup-member.ps1 -username $env:CATS_MEMBER -sid S-1-5-32-555 -remove; exit $LASTEXITCODE"
	if errorlevel 2 exit /b 2
	exit /b 0
)

echo [36mRECIPE    : Adding %~1 to the Remote Desktop Users group [0m
powershell -noprofile -executionpolicy bypass -command "& %CATS_ROOT%\ps\set-localgroup-member.ps1 -username $env:CATS_MEMBER -sid S-1-5-32-555; exit $LASTEXITCODE"
if errorlevel 2 exit /b 2

rem A group policy that sets the switch wins over Settings, so its value
rem is the one read when there is one
set "UR_KEY=HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server"
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v fDenyTSConnections >nul 2>nul
if not errorlevel 1 set "UR_KEY=HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"
reg query "%UR_KEY%" /v fDenyTSConnections 2>nul | find /i "0x1" >nul
if not errorlevel 1 (
	echo [33mWARNING   : Remote Desktop is turned off on this machine: %~1 is a member, but cannot connect until it is turned on - Settings, System, Remote Desktop, or the group policy that turns it off [0m
	exit /b 2
)
exit /b 0
