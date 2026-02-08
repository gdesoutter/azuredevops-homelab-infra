param (
    [string]$TenantId,
    [string]$ClientId,
    [string]$ClientSecret,
    [string]$ResourceGroup,
    [string]$Location,
    [string]$ResourceName = "ARC-SRV-01"
)

$ErrorActionPreference = "Stop"

# 1. Renommage de l'ordinateur (Hostname OS)
$CurrentName = $env:COMPUTERNAME
if ($CurrentName -ne $ResourceName) {
    Write-Host "Renaming computer from $CurrentName to $ResourceName..."
    Rename-Computer -NewName $ResourceName -Force
}

# 2. Installation de l'agent si nécessaire
if (-not (Test-Path "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe")) {
    Write-Host "Downloading Azure Arc agent..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri "https://aka.ms/AzureConnectedMachineAgent" -OutFile "AzureConnectedMachineAgent.msi"
    
    Write-Host "Installing Azure Arc agent..."
    Start-Process msiexec.exe -ArgumentList '/i AzureConnectedMachineAgent.msi /qn /l*v "install.log"' -Wait
}

# 3. Connexion à Azure Arc
Write-Host "Connecting to Azure Arc as $ResourceName in $ResourceGroup ($Location)..."


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

& "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" @azcmParams

Write-Host "Machine $ResourceName onboarded successfully."