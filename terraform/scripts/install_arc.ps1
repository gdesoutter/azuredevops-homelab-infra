param (
    [string]$TenantId, [string]$ClientId, [string]$ClientSecret,
    [string]$ResourceGroup, [string]$Location, [string]$ResourceName,
    [string]$SubscriptionId
)

$ErrorActionPreference = "Stop"

try {
    if ($env:COMPUTERNAME -ne $ResourceName) { 
        Write-Host "Renommage de la machine..."
        Rename-Computer -NewName $ResourceName -Force 
    }

    $agentExe = "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe"

    if (-not (Test-Path $agentExe)) {
        Write-Host "Téléchargement de l'agent (MSI Officiel)..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
        
        $url = "https://aka.ms/AzureConnectedMachineAgent"
        $msiPath = "C:\Temp\AzureConnectedMachineAgent.msi"

        Invoke-WebRequest -Uri $url -OutFile $msiPath -UseBasicParsing

        if ((Get-Item $msiPath).Length -lt 50000000) {
            throw "ERREUR CRITIQUE: Le fichier téléchargé est trop petit. Ce n'est pas le MSI."
        }

        Write-Host "Installation MSI..."
        $proc = Start-Process msiexec.exe -ArgumentList "/i $msiPath /qn /l*v C:\Temp\install.log" -Wait -PassThru
        
        if ($proc.ExitCode -ne 0) {
            throw "Echec installation MSI. Code: $($proc.ExitCode)"
        }
    }

    Write-Host "Attente de l'initialisation du service Agent..."
    $maxRetries = 30
    $ready = $false

    for ($i = 0; $i -lt $maxRetries; $i++) {
        $status = & $agentExe show --json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
        
        if ($status) {
            Write-Host "Agent prêt détecté."
            $ready = $true
            break
        }
        
        Write-Host "L'agent s'initialise... (Tentative $($i+1)/$maxRetries)"
        Start-Sleep -Seconds 10
    }

    if (-not $ready) {
        throw "TIMEOUT: L'agent ne s'est pas initialisé après 5 minutes."
    }

    # --- 4. CONNEXION ---
    Write-Host "Connexion à Azure Arc..."
    & $agentExe connect `
      --service-principal-id "$ClientId" `
      --service-principal-secret "$ClientSecret" `
      --tenant-id "$TenantId" `
      --subscription-id "$SubscriptionId" `
      --resource-group "$ResourceGroup" `
      --location "$Location" `
      --resource-name "$ResourceName" `
      --correlation-id "terraform-deploy" --verbose

    Write-Host "SUCCÈS : Machine connectée."

}
catch {
    Write-Error "ÉCHEC CRITIQUE : $_"
    exit 1
}