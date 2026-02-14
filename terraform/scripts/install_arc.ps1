param (
    [string]$TenantId, [string]$ClientId, [string]$ClientSecret,
    [string]$ResourceGroup, [string]$Location, [string]$ResourceName,
    [string]$SubscriptionId
)

$ErrorActionPreference = "Stop"
$logFile = "C:\Temp\onboarding_debug.log"

function Log-Message($msg) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $msg"
    "[$timestamp] $msg" | Out-File -FilePath $logFile -Append
}

try {
    $agentExe = "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe"
    
    if (-not (Test-Path $agentExe)) {
        Log-Message "Agent manquant. Téléchargement..."
        $url = "https://aka.ms/AzureConnectedMachineAgent"
        $msiPath = "C:\Temp\AzureConnectedMachineAgent.msi"
        Invoke-WebRequest -Uri $url -OutFile $msiPath -UseBasicParsing
        Start-Process msiexec.exe -ArgumentList "/i $msiPath /qn" -Wait
    }

    Log-Message "Nettoyage des tentatives précédentes..."
    & $agentExe disconnect --force-local-only 2>$null

    Log-Message "Attente que le service HIMDS soit prêt (Lock-Check)..."
    $ready = $false
    $timeout = [System.Diagnostics.Stopwatch]::StartNew()
    
    while ($timeout.Elapsed.TotalMinutes -lt 12) {
        $status = & $agentExe show --json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($status) {
            Log-Message "Agent déverrouillé après $($timeout.Elapsed.TotalMinutes) min."
            $ready = $true
            break
        }
        Log-Message "Agent encore en inventaire matériel... On patiente."
        Start-Sleep -Seconds 30
    }

    if (-not $ready) { throw "Timeout de 12 min atteint." }

    Log-Message "Lancement de la connexion finale..."
    & $agentExe connect `
      --service-principal-id "$ClientId" `
      --service-principal-secret "$ClientSecret" `
      --tenant-id "$TenantId" `
      --subscription-id "$SubscriptionId" `
      --resource-group "$ResourceGroup" `
      --location "$Location" `
      --resource-name "$ResourceName" `
      --cloud "AzureCloud" `
      --tags 'Source=Terraform_Lab' `

    Log-Message "Vérification finale..."
    $check = & $agentExe show --json | ConvertFrom-Json
    if ($check.status -eq "Connected") {
        Log-Message "SUCCÈS : Machine en ligne dans Azure."
    } else {
        throw "La commande a fini mais le statut est : $($check.status)"
    }

}
catch {
    Log-Message "ERREUR : $_"
    exit 1
}