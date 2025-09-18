param policyDefinitionId string
param requiredTagName string = 'owner'
param scope string = subscription().id

resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: 'enforce-required-tag'
  properties: {
    displayName: 'Enforce Required Tag'
    scope: scope
    policyDefinitionId: policyDefinitionId
    enforcementMode: 'Default'
    parameters: {
      requiredTagName: { value: requiredTagName }
    }
  }
}
