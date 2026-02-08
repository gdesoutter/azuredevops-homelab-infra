param (
    [string]$TenantId,
    [string]$ClientId,
    [string]$ClientSecret,
    [string]$ResourceGroup,
    [string]$Location,
    [string]$ResourceName = "ARC-SRV-01"
)

$ErrorActionPreference = "Stop"
$LogFile = "C:\Temp\arc_connection_result.txt"

# 1. Validation de sécurité : Si Terraform envoie du vide, on arrête tout de suite
if ([string]::IsNullOrWhiteSpace($ClientSecret) -or [string]::IsNullOrWhiteSpace($ClientId)) {
    Write-Error "Erreur : ClientId ou ClientSecret est vide. Vérifie ton main.tf."
    exit 1
}

# 2. Renommage de l'OS
if ($env:COMPUTERNAME -ne $ResourceName) {
    Write-Host "Renaming computer to $ResourceName..."
    Rename-Computer -NewName $ResourceName -Force
}

# 3. Installation de l'agent
$agentPath = "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe"
if (-not (Test-Path $agentPath)) {
    Write-Host "Downloading and Installing Azure Arc agent..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri "https://aka.ms/AzureConnectedMachineAgent" -OutFile "C:\Temp\AzureConnectedMachineAgent.msi"
    Start-Process msiexec.exe -ArgumentList '/i C:\Temp\AzureConnectedMachineAgent.msi /qn /l*v "C:\Temp\msi_install.log"' -Wait
}

# 4. Attente active du binaire (indispensable pour l'auto)
$timeout = Get-Date; $max = 60
while (-not (Test-Path $agentPath)) {
    if ((Get-Date) -gt $timeout.AddSeconds($max)) { Write-Error "Timeout installation agent."; exit 1 }
    Start-Sleep -Seconds 5
}

# 5. Connexion avec capture de log locale
Write-Host "Attempting Arc connection for $ResourceName..."
$azcmParams = @(
    "connect",
    "--service-principal-id", $ClientId,
    "--service-principal-secret", $ClientSecret,
    "--tenant-id", $TenantId,
    "--resource-group", $ResourceGroup,
    "--location", $Location,
    "--resource-name", $ResourceName
)

# On redirige tout (standard et erreur) vers le fichier log pour que TU puisses lire la cause si ça échoue
& $agentPath @azcmParams > $LogFile 2>&1

# 6. Vérification finale du statut
$status = & $agentPath show
if ($status -match "Connected") {
    Write-Host "Machine $ResourceName onboarded successfully."
} else {
    Write-Error "Connection failed. Content of $LogFile : $(Get-Content $LogFile)"
    exit 1
}