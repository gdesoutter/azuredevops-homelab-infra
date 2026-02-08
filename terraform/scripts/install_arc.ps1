param (
    [string]$TenantId,
    [string]$ClientId,
    [string]$ClientSecret,
    [string]$ResourceGroup,
    [string]$Location,
    [string]$ResourceName,
    [string]$SubscriptionId = "c5a7cedd-785a-44ea-a3fb-dfda4063fa77"
)

$ErrorActionPreference = "Stop"

# 1. Renommage de l'OS (Déjà validé comme fonctionnel)
if ($env:COMPUTERNAME -ne $ResourceName) {
    Write-Host "Renaming computer to $ResourceName..."
    Rename-Computer -NewName $ResourceName -Force
}

# 2. Installation de l'agent (Via l'URL officielle du portail)
$agentPath = "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe"
if (-not (Test-Path $agentPath)) {
    Write-Host "Downloading official Azure Arc agent..."
    $installScriptPath = "C:\Temp\install_windows_azcmagent.ps1"
    if (-not (Test-Path "C:\Temp")) { New-Item -Path "C:\Temp" -ItemType Directory }
    
    Invoke-WebRequest -Uri "https://gbl.his.arc.azure.com/azcmagent-windows" -OutFile $installScriptPath
    & $installScriptPath
}

# 3. BOUCLE DE RETRY - La solution au problème "Agent is initialized"
# Ton log himds 3.log montre que l'agent bloque la connexion tant qu'il scanne le hardware.
$maxRetries = 10
$retryCount = 0
$connected = $false

while (-not $connected -and $retryCount -lt $maxRetries) {
    # On vérifie si la machine est déjà connectée (pour éviter de re-faire le travail)
    $status = & $agentPath show
    if ($status -match "Connected|Connecté") {
        Write-Host "Machine is already connected."
        $connected = $true
        break
    }

    Write-Host "Attempting connection ($($retryCount + 1)/$maxRetries)..."
    
    # Commande de connexion avec les paramètres officiels
    & $agentPath connect `
      --service-principal-id $ClientId `
      --service-principal-secret $ClientSecret `
      --tenant-id $TenantId `
      --subscription-id $SubscriptionId `
      --resource-group $ResourceGroup `
      --location $Location `
      --resource-name $ResourceName `
      --cloud "AzureCloud" `
      --tags 'ArcSQLServerExtensionDeployment=Disabled' `
      --correlation-id "Terraform-$(Get-Random)"

    if ($LASTEXITCODE -eq 0) {
        $connected = $true
        Write-Host "Successfully connected to Azure Arc."
    } else {
        # Si on voit l'erreur d'initialisation dans le log, on attend
        Write-Host "Agent still initializing or busy. Retrying in 30 seconds..."
        Start-Sleep -Seconds 30
        $retryCount++
    }
}

if (-not $connected) {
    Write-Error "Failed to connect to Azure Arc after $maxRetries attempts."
    exit 1
}