$appName = "Windows App"
$appId = "9n1f85v9t8bn"

# Funzione per verificare se l'applicazione è installata
function Is-AppInstalled {
	param (
		[string]$appName
	)
	
	# Usa Get-StartApps per ottenere la lista delle applicazioni installate
	$installedApps = Get-StartApps

	# Verifica se l'applicazione è nella lista
	foreach ($app in $installedApps) {
		if ($app.Name -like "*$appName*") {
			return $true
		}
	}
	return $false
}

# Funzione per installare l'applicazione usando Winget
function Install-App {
	param (
		[string]$appId
	)
	
	# Verifica se Winget è disponibile
	if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
		Write-Error "Winget non è installato. Installa Winget prima di procedere."
		exit 1
	}

	# Installa l'applicazione
	winget install --id=$appId --silent --accept-package-agreements --accept-source-agreements
}

# Verifica se l'applicazione è installata
if (-not (Is-AppInstalled -appName $appName)) {
	Write-Output "$appName Installazione in corso..."
	Install-App -appId $appId
} else {
	Write-Output "$appName presente"
}
