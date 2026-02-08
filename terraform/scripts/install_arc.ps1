param (
    [string]$TenantId, [string]$ClientId, [string]$ClientSecret,
    [string]$ResourceGroup, [string]$Location, [string]$ResourceName,
    [string]$SubscriptionId = "c5a7cedd-785a-44ea-a3fb-dfda4063fa77"
)

$ErrorActionPreference = "Continue"

# 1. Renommage et Installation (On ne change pas ce qui marche)
if ($env:COMPUTERNAME -ne $ResourceName) { Rename-Computer -NewName $ResourceName -Force }
$agentPath = "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe"
$configPath = "C:\ProgramData\AzureConnectedMachineAgent\Config\agentconfig.json"

if (-not (Test-Path $agentPath)) {
    Invoke-WebRequest -Uri "https://gbl.his.arc.azure.com/azcmagent-windows" -OutFile "C:\Temp\agent.msi"
    Start-Process msiexec.exe -ArgumentList '/i C:\Temp\agent.msi /qn' -Wait
}

# 2. La boucle de patience absolue (On attend le déverrouillage réel)
Write-Host "Attente du déverrouillage de l'agent (Cible : 10 minutes)..."
$isInitialized = $false
$attempts = 0
while (-not $isInitialized -and $attempts -lt 60) {
    $test = & $agentPath show 2>$null
    # On vérifie que l'agent ne renvoie PLUS l'erreur d'initialisation du log
    if ($test -and $test -notmatch "until agent is initialized") {
        $isInitialized = $true
        Write-Host "L'agent est déverrouillé et prêt pour l'onboarding."
    } else {
        Write-Host "Agent encore en phase de scan matériel... (Minute $([math]::Round($attempts*15/60,1)))"
        Start-Sleep -Seconds 15
        $attempts++
    }
}

# 3. Tentative de connexion
Write-Host "Lancement de la connexion Azure Arc..."
& $agentPath connect `
  --service-principal-id "$ClientId" `
  --service-principal-secret "$ClientSecret" `
  --tenant-id "$TenantId" `
  --subscription-id "$SubscriptionId" `
  --resource-group "$ResourceGroup" `
  --location "$Location" `
  --resource-name "$ResourceName" `
  --cloud "AzureCloud" `
  --tags 'ArcSQLServerExtensionDeployment=Disabled'

# 4. LA VÉRIFICATION FINALE
if (Test-Path $configPath) {
    Write-Host "SUCCÈS : Le fichier agentconfig.json est présent. La machine va remonter sur le portail."
    exit 0
} else {
    Write-Error "ÉCHEC CRITIQUE : La commande connect a fini mais le fichier de config est absent."
    exit 1
}