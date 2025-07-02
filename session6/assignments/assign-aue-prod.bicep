targetScope = 'subscription'

param policyDefinitionId string

resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: 'enforce-aue-only'
  properties: {
    displayName: 'Enforce Australia East Region Only'
    policyDefinitionId: policyDefinitionId
    scope: subscription().id
    enforcementMode: 'Default'
  }
}
