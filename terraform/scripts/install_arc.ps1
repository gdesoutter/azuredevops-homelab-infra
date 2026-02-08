param (
    [string]$TenantId,
    [string]$ClientId,
    [string]$ClientSecret,
    [string]$ResourceGroup,
    [string]$Location,
    [string]$ResourceName = "ARC-SRV-01"
)

$ErrorActionPreference = "Stop"

# 1. Renommage de l'ordinateur
if ($env:COMPUTERNAME -ne $ResourceName) {
    Write-Host "Renaming computer to $ResourceName..."
    Rename-Computer -NewName $ResourceName -Force
}

# 2. Installation de l'agent
$agentPath = "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe"
if (-not (Test-Path $agentPath)) {
    Write-Host "Downloading and Installing Azure Arc agent..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri "https://aka.ms/AzureConnectedMachineAgent" -OutFile "C:\Temp\AzureConnectedMachineAgent.msi"
    Start-Process msiexec.exe -ArgumentList '/i C:\Temp\AzureConnectedMachineAgent.msi /qn' -Wait
}

# 3. ATTENTE CRUCIALE DE L'INITIALISATION (Nouveau)
Write-Host "Waiting for Arc Service to be ready (Initialization phase)..."
$isReady = $false
$retryCount = 0
while (-not $isReady -and $retryCount -lt 20) {
    # On teste si le service répond sans l'erreur 'until agent is initialized'
    $testStatus = & $agentPath show
    if ($testStatus -match "Disconnected|Unconnected|Connected|Connecté") {
        $isReady = $true
        Write-Host "Agent service is initialized and ready."
    } else {
        Write-Host "Service still initializing... (Attempt $($retryCount + 1)/20)"
        Start-Sleep -Seconds 10
        $retryCount++
    }
}

# 4. Connexion avec gestion des erreurs améliorée
Write-Host "Connecting to Azure Arc..."
$azcmParams = @(
    "connect",
    "--service-principal-id", $ClientId,
    "--service-principal-secret", $ClientSecret,
    "--tenant-id", $TenantId,
    "--resource-group", $ResourceGroup,
    "--location", $Location,
    "--resource-name", $ResourceName
)

& $agentPath @azcmParams

if ($LASTEXITCODE -ne 0) {
    Write-Error "Onboarding failed with exit code $LASTEXITCODE. Check C:\ProgramData\AzureConnectedMachineAgent\Log\himds.log"
    exit 1
}

Write-Host "Success: Machine $ResourceName is now connected to Azure Arc."