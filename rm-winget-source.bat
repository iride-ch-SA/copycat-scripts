@echo off
REM ============================================================
REM  rm-winget-source.bat
REM  Rimuove Microsoft.Winget.Source (per utente + provisioning)
REM  per sbloccare sysprep. Eseguire come Amministratore.
REM  NON riavviare tra questo script e sysprep.
REM ============================================================

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERRORE] Eseguire questo script come Amministratore.
    pause
    exit /b 1
)

echo Rimozione di Microsoft.Winget.Source in corso...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='SilentlyContinue';" ^
  "$pkgs = Get-AppxPackage -AllUsers Microsoft.Winget.Source;" ^
  "if ($pkgs) {" ^
    "foreach ($p in $pkgs) {" ^
      "Write-Host ('Rimozione per utente: ' + $p.PackageFullName);" ^
      "Remove-AppxPackage -AllUsers -Package $p.PackageFullName;" ^
    "}" ^
  "} else { Write-Host 'Nessun pacchetto per utente trovato.' }" ^
  "$prov = Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq 'Microsoft.Winget.Source';" ^
  "if ($prov) {" ^
    "foreach ($pp in $prov) {" ^
      "Write-Host ('Rimozione provisioning: ' + $pp.PackageName);" ^
      "Remove-AppxProvisionedPackage -Online -PackageName $pp.PackageName;" ^
    "}" ^
  "} else { Write-Host 'Nessun provisioning trovato.' }"

echo.
echo Operazione completata.
echo.
pause
