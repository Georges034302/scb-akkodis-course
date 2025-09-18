targetScope = 'subscription'

param policyDefinitionId string
param listOfAllowedSKUs array = [
  'Standard_B1s'
  'Standard_B2s'
]

resource pa 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: 'enforce-allowed-vm-sizes'
  properties: {
    displayName: 'Enforce Allowed VM Sizes'
    policyDefinitionId: policyDefinitionId
    enforcementMode: 'Default'
    parameters: {
      listOfAllowedSKUs: {
        value: listOfAllowedSKUs
      }
    }
  }
}
