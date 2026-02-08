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

# 1. Renommage de l'OS
if ($env:COMPUTERNAME -ne $ResourceName) {
    Write-Host "Renaming computer to $ResourceName..."
    Rename-Computer -NewName $ResourceName -Force
}

# 2. Installation de l'agent (Via l'URL officielle)
$agentPath = "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe"
if (-not (Test-Path $agentPath)) {
    Write-Host "Downloading and Installing Azure Arc agent..."
    if (-not (Test-Path "C:\Temp")) { New-Item -Path "C:\Temp" -ItemType Directory }
    $installScriptPath = "C:\Temp\install_windows_azcmagent.ps1"
    Invoke-WebRequest -Uri "https://gbl.his.arc.azure.com/azcmagent-windows" -OutFile $installScriptPath
    & $installScriptPath
}

# 3. Attente de l'initialisation (Max 3 minutes)
# C'est ici qu'on corrige l'erreur "failed to obtain change token" vue dans le log
Write-Host "Waiting for agent initialization..."
$isReady = $false
$attempts = 0
while (-not $isReady -and $attempts -lt 18) {
    $test = & $agentPath show
    # Si le statut apparaît (même Disconnected), le verrou de sécurité est levé
    if ($test -match "Disconnected|Unconnected|Connected") {
        $isReady = $true
        Write-Host "Agent is ready."
    } else {
        Write-Host "Service busy (initializing)... Attempt $($attempts + 1)/18"
        Start-Sleep -Seconds 10
        $attempts++
    }
}

if (-not $isReady) { throw "Timeout: Agent service never finished initialization." }

# 4. Connexion avec Retry (Max 3 tentatives)
$connected = $false
$retryConnect = 0
while (-not $connected -and $retryConnect -lt 3) {
    Write-Host "Connecting to Azure Arc (Attempt $($retryConnect + 1)/3)..."
    & $agentPath connect `
      --service-principal-id "$ClientId" `
      --service-principal-secret "$ClientSecret" `
      --tenant-id "$TenantId" `
      --subscription-id "$SubscriptionId" `
      --resource-group "$ResourceGroup" `
      --location "$Location" `
      --resource-name "$ResourceName" `
      --cloud "AzureCloud"