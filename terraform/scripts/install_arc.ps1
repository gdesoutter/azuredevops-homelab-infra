param (
    [string]$TenantId,
    [string]$ClientId,
    [string]$ClientSecret,
    [string]$ResourceGroup,
    [string]$Location,
    [string]$ResourceName,
    [string]$SubscriptionId = "c5a7cedd-785a-44ea-a3fb-dfda4063fa77"
)

# On commence en "Continue" pour ne pas tuer le script si l'agent répond une erreur au début
$ErrorActionPreference = "Continue"

# 1. Renommage de l'OS (Déjà validé)
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
Write-Host "Waiting for agent initialization (Target: 10-15 minutes)..."
$isReady = $false
$attempts = 0

while (-not $isReady -and $attempts -lt 60) {
    # On redirige les erreurs vers le néant (2>$null) pour ne pas polluer les logs
    # et on vérifie si la commande s'exécute sans erreur (ExitCode 0)
    $testStatus = & $agentPath show 2>$null
    
    if ($LASTEXITCODE -eq 0 -and ($testStatus -match "Disconnected|Unconnected|Connected|Connecté")) {
        $isReady = $true
        $totalMinutes = [math]::Round(($attempts * 15) / 60, 1)
        Write-Host "Agent is finally ready after $totalMinutes minutes."
    } else {
        Write-Host "Agent still busy/initializing... (Attempt $($attempts + 1)/60)"
        Start-Sleep -Seconds 15
        $attempts++
    }
}

# 4. Connexion finale
if ($isReady) {
    # On repasse en "Stop" pour que si la CONNEXION échoue, Terraform le sache
    $ErrorActionPreference = "Stop"
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
      
    Write-Host "Onboarding Successful."
} else {
    Write-Error "Timeout: Agent initialization exceeded 15 minutes."
    exit 1
}