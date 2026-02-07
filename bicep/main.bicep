// Fichier: bicep/main.bicep
param location string = resourceGroup().location

// 'st' + un hash unique basé sur l'ID du groupe de ressources
var storageName = 'st${uniqueString(resourceGroup().id)}'

// La ressource réelle
resource storageaccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS' // Stockage le moins cher pour le test
  }
}

// On affiche le nom du stockage créé à la fin
output storageName string = storageaccount.name
