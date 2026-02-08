// 1. Définition des paramètres (Le Contrat)
param location string = resourceGroup().location
param vmName string

param storageAccountName string
@secure()
param storageAccountKey string
param domainJoinUser string
@secure()
param domainJoinPassword string


resource arcMachine 'Microsoft.HybridCompute/machines@2022-03-10' existing = {
  name: vmName
}

// 3. Déploiement de l'extension DSC
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
        // Configuration publique
        wmfVersion: 'latest'
        configuration: {
            url: 'https://github.com/PowerShell/PSDscResources/archive/refs/heads/master.zip'
            function: 'ExampleConfig'
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
