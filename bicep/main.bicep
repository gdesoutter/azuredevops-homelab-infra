param location string = resourceGroup().location
param vmName string 

// On cible la machine Azure Arc (Microsoft.HybridCompute)
resource arcMachine 'Microsoft.HybridCompute/machines@2022-03-10' existing = {
  name: vmName
}

// On installe l'extension DSC
resource dscExtension 'Microsoft.HybridCompute/machines/extensions@2022-03-10' = {
  parent: arcMachine
  name: 'DSC'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.83'
    autoUpgradeMinorVersion: true
    settings: {
        configurationArguments: {
            RegistrationUrl: '...' // Si tu utilises Azure Automation
        }
    }
  }
}
