targetScope = 'subscription'

param policyDefinitionId string
param requiredTagName string = 'owner'

resource assignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: 'enforce-required-tag'
  properties: {
    displayName: 'Enforce Required Tag'
    policyDefinitionId: policyDefinitionId
    enforcementMode: 'Default'
    parameters: {
      requiredTagName: { value: requiredTagName }
    }
  }
}
