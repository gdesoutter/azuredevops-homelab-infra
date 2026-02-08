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

# 1. Renommage de l'OS (Déjà validé dans les logs)
if ($env:COMPUTERNAME -ne $ResourceName) {
    Write-Host "Renaming computer to $ResourceName..."
    Rename-Computer -NewName $ResourceName -Force
}

# 2. Installation de l'agent
$agentPath = "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe"
if (-not (Test-Path $agentPath)) {
    Write-Host "Installing Azure Arc agent..."
    Invoke-WebRequest -Uri "https://gbl.his.arc.azure.com/azcmagent-windows" -OutFile "C:\Temp\agent.msi"
    Start-Process msiexec.exe -ArgumentList '/i C:\Temp\agent.msi /qn' -Wait
}

# 3. Boucle d'attente d'initialisation (Réglée sur 15 minutes max)
# On attend que l'erreur "Cannot onboard... until agent is initialized" disparaisse
Write-Host "Waiting for agent initialization (This can take up to 10-15 minutes in your lab)..."
$isReady = $false
$attempts = 0
while (-not $isReady -and $attempts -lt 60) {
    $testStatus = & $agentPath show
    if ($testStatus -match "Disconnected|Unconnected|Connected|Connecté") {
        $isReady = $true
        Write-Host "Agent is finally ready after $($attempts * 15 / 60) minutes."
    } else {
        Write-Host "Agent still busy. Waiting 15s... (Attempt $($attempts + 1)/60)"
        Start-Sleep -Seconds 15
        $attempts++
    }
}

if (-not $isReady) { throw "Timeout: Agent initialized too slowly (Exceeded 15 min)." }

# 4. Connexion finale
Write-Host "Connecting to Azure Arc..."
& $agentPath connect `
  --service-principal-id "$ClientId" `
  --service-principal-secret "$ClientSecret" `
  --tenant-id "$TenantId" `
  --subscription-id "$SubscriptionId" `
  --resource-group "$ResourceGroup" `
  --location "$Location" `
  --resource-name "$ResourceName" `
  --cloud "AzureCloud" `
  --tags 'ArcSQLServerExtensionDeployment=Disabled' `
  --correlation-id "Terraform-$(Get-Random)"

if ($LASTEXITCODE -eq 0) { Write-Host "Onboarding Successful." } else { exit 1 }