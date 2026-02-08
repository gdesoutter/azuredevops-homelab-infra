param (
    [string]$TenantId,
    [string]$ClientId,
    [string]$ClientSecret,
    [string]$ResourceGroup,
    [string]$Location,
    [string]$ResourceName = "ARC-SRV-01"
)

$ErrorActionPreference = "Stop"

# 1. Renommage de l'OS (Hostname local)
# On le fait en premier pour que l'agent détecte le nom final souhaité
$CurrentName = $env:COMPUTERNAME
if ($CurrentName -ne $ResourceName) {
    Write-Host "Renaming computer from $CurrentName to $ResourceName..."
    Rename-Computer -NewName $ResourceName -Force
}

# 2. Installation de l'agent si nécessaire
$agentPath = "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe"

if (-not (Test-Path $agentPath)) {
    Write-Host "Downloading Azure Arc agent..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri "https://aka.ms/AzureConnectedMachineAgent" -OutFile "AzureConnectedMachineAgent.msi"
    
    Write-Host "Installing Azure Arc agent (MSI)..."
    $process = Start-Process msiexec.exe -ArgumentList '/i AzureConnectedMachineAgent.msi /qn /l*v "install.log"' -Wait -PassThru
    
    # 3. Boucle de sécurité : On attend que Windows finisse d'écrire le fichier sur le disque
    $maxAttempts = 12
    $attempt = 0
    while (-not (Test-Path $agentPath) -and ($attempt -lt $maxAttempts)) {
        Write-Host "Waiting for azcmagent.exe to be ready... (Attempt $($attempt + 1)/$maxAttempts)"
        Start-Sleep -Seconds 5
        $attempt++
    }
}

if (-not (Test-Path $agentPath)) {
    Write-Error "Critical: Azure Arc Agent binary not found after installation. Check install.log."
    exit 1
}

# 4. Connexion à Azure Arc
Write-Host "Connecting to Azure Arc as $ResourceName..."

# Utilisation du splatting pour éviter les erreurs de syntaxe des backticks (`)
$azcmParams = @(
    "connect",
    "--service-principal-id", $ClientId,
    "--service-principal-secret", $ClientSecret,
    "--tenant-id", $TenantId,
    "--resource-group", $ResourceGroup,
    "--location", $Location,
    "--resource-name", $ResourceName, 
    "--correlation-id", "Terraform-$(Get-Random)"
)

& $agentPath @azcmParams

Write-Host "Machine $ResourceName onboarded successfully."