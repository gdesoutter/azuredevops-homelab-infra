trigger:
- main

variables:
  azureServiceConnection: 'Azure-Subscription-Conn'
  resourceGroupName: 'RG-HYBRID-LAB'
  location: 'westeurope'
  templateFile: 'bicep/main.bicep'

pool:
  name: 'Default' 

stages:
- stage: Validate
  jobs:
  - job: Lint_And_Validate
    steps:
    - task: AzureCLI@2
      displayName: 'Bicep Linter & ARM Validation'
      inputs:
        azureSubscription: $(azureServiceConnection)
        scriptType: 'pscore'
        scriptLocation: 'inlineScript'
        inlineScript: |
          # 1. Basic Build/Lint
          az bicep build --file $(templateFile)
          
          # 2. Cloud-side Validation (Deployment Check)
          az deployment group validate `
            --resource-group $(resourceGroupName) `
            --template-file $(templateFile)

- stage: Preview
  dependsOn: Validate
  jobs:
  - job: WhatIf
    steps:
    - task: AzureCLI@2
      displayName: 'What-If Analysis'
      inputs:
        azureSubscription: $(azureServiceConnection)
        scriptType: 'pscore'
        scriptLocation: 'inlineScript'
        inlineScript: |
          az deployment group what-if `
            --resource-group $(resourceGroupName) `
            --template-file $(templateFile)

- stage: Deploy
  dependsOn: Preview
  condition: succeeded()
  jobs:
  - deployment: Bicep_Deployment
    environment: 'Production' # Adds a manual approval gate in Azure DevOps UI
    strategy:
      runOnce:
        deploy:
          steps:
          - task: AzureResourceManagerTemplateDeployment@3
            inputs:
              deploymentScope: 'Resource Group'
              azureResourceManagerConnection: $(azureServiceConnection)
              action: 'Create Or Update Resource Group'
              resourceGroupName: $(resourceGroupName)
              location: $(location)
              templateLocation: 'Linked artifact'
              csmFile: $(templateFile)
              deploymentMode: 'Incremental'
