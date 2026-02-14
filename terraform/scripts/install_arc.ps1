param (
    [string]$TenantId, [string]$ClientId, [string]$ClientSecret,
    [string]$ResourceGroup, [string]$Location, [string]$ResourceName,
    [string]$SubscriptionId
)

$ErrorActionPreference = "Stop"

try {
    $agentExe = "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe"
    if (-not (Test-Path $agentExe)) {
        Write-Host "Installation de l'agent..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
        $url = "https://aka.ms/AzureConnectedMachineAgent"
        $msiPath = "C:\Temp\AzureConnectedMachineAgent.msi"
        Invoke-WebRequest -Uri $url -OutFile $msiPath -UseBasicParsing
        Start-Process msiexec.exe -ArgumentList "/i $msiPath /qn" -Wait
    }

    Write-Host "Vérification du service Hybrid Instance Metadata Service (himds)..."
    $svc = Get-Service himds -ErrorAction SilentlyContinue
    if ($svc.Status -ne 'Running') {
        Start-Service himds
        Start-Sleep -Seconds 5
    }

    Write-Host "Attente de la fin du scan matériel (Peut prendre plusieurs minutes sur ton Lab)..."
    $isReady = $false
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    
    while ($timer.Elapsed.TotalMinutes -lt 10) {
        $test = & $agentExe show --json 2>$null
        if ($LASTEXITCODE -eq 0 -and $test) {
            Write-Host "L'agent est réveillé et prêt après $($timer.Elapsed.TotalMinutes) minutes."
            $isReady = $true
            break
        }
        Write-Host "Agent encore occupé... On attend 20 secondes. (Temps écoulé : $([math]::Round($timer.Elapsed.TotalMinutes, 1)) min)"
        Start-Sleep -Seconds 20
    }

    if (-not $isReady) { throw "L'agent n'a pas fini son initialisation après 10 minutes. Abandon." }

    Write-Host "Lancement de la connexion Azure Arc..."
    $connected = $false
    for ($retry=1; $retry -le 3; $retry++) {
        & $agentExe connect `
          --service-principal-id "$ClientId" `
          --service-principal-secret "$ClientSecret" `
          --tenant-id "$TenantId" `
          --subscription-id "$SubscriptionId" `
          --resource-group "$ResourceGroup" `
          --location "$Location" `
          --resource-name "$ResourceName" `
          --cloud "AzureCloud" `
          --tags 'ArcSQLServerExtensionDeployment=Disabled'

        if ($LASTEXITCODE -eq 0) {
            $connected = $true
            break
        }
        Write-Warning "Tentative de connexion $retry échouée. Nouvelle tentative dans 30s..."
        Start-Sleep -Seconds 30
    }

    if (-not $connected) { throw "Impossible de connecter la machine à Azure Arc après 3 tentatives." }

    Write-Host "SUCCÈS : Machine $ResourceName connectée et provisionnée."
}
catch {
    Write-Error "ÉCHEC : $_"
    exit 1
}