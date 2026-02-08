// 1. Définition des paramètres
param location string = resourceGroup().location
param vmName string
param domainJoinUser string

@secure()
param domainJoinPassword string

// Ce paramètre recevra l'URL SAS de ton fichier DomainJoin.zip
param dscZipUrl string 

// 2. Référence à la machine Arc existante
// On utilise la version 2022-12-27, plus stable pour les extensions
resource arcMachine 'Microsoft.HybridCompute/machines@2022-12-27' existing = {
  name: vmName
}

// 3. Déploiement de l'extension DSC
resource dscExtension 'Microsoft.HybridCompute/machines/extensions@2022-12-27' = {
  parent: arcMachine
  name: 'DSC'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.83'
    autoUpgradeMinorVersion: true
    settings: {
        wmfVersion: 'latest'
        configuration: {
            url: dscZipUrl
            function: 'DomainJoin' 
        }
    }
    protectedSettings: {
        configurationArguments: {
            domainJoinUser: domainJoinUser
            domainJoinPassword: domainJoinPassword
        }
    }
  }
}
