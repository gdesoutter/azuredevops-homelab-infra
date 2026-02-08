param (
    [string]$TenantId,
    [string]$ClientId,
    [string]$ClientSecret,
    [string]$ResourceGroup,
    [string]$Location,
    [string]$ResourceName
)

$ErrorActionPreference = "Stop"


if (-not (Test-Path "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe")) {
    Write-Host "Downloading Azure Arc agent..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri "https://aka.ms/AzureConnectedMachineAgent" -OutFile "AzureConnectedMachineAgent.msi"
    
    Write-Host "Installing Azure Arc agent..."
    Start-Process msiexec.exe -ArgumentList '/i AzureConnectedMachineAgent.msi /qn /l*v "install.log"' -Wait
}


Write-Host "Connecting to Azure Arc as $ResourceName..."
& "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" connect `
  --service-principal-id $ClientId `
  --service-principal-secret $ClientSecret `
  --tenant-id $TenantId `
  --resource-group $ResourceGroup `
  --location $Location `
  --resource-name $ResourceName `
  --correlation-id "Terraform-$(Get-Random)"

Write-Host "Machine onboarded successfully."