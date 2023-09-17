targetScope = 'subscription'

@description('Location of deployment')
param location string = 'westeurope'

@description('List of resource group Ids')
param resourceGroupIds object = {
  identity: '/subscriptions/ef6ea1fb-82dd-46bb-a72d-f36c20802858/resourceGroups/rg-identity-001-jdaz72-corp-dev'
  management: '/subscriptions/ef6ea1fb-82dd-46bb-a72d-f36c20802858/resourceGroups/rg-management-001-jdaz72-corp-dev'
}

var builtinPoliciesRg = [
  {
    displayName: 'Deploy prerequisites to enable Guest Configuration policies on virtual machines'
    policyDefinitionId: '/providers/Microsoft.Authorization/policySetDefinitions/12794019-7a00-42cf-95c2-882eed337cc8'
    identity: 'SystemAssigned'
    scope: resourceGroupIds.identity
    effect: ''

  }
  {
    displayName: 'Configure periodic checking for missing system updates on azure virtual machines'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/59efceea-0c96-497e-a4a1-4eb2290dac15'
    identity: 'SystemAssigned'
    scope: resourceGroupIds.identity
    effect: ''
  }
  {
    displayName: 'Storage account encryption scopes should use double encryption for data at rest'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/bfecdea6-31c4-4045-ad42-71b9dc87247d'
    identity: 'None'
    scope: resourceGroupIds.management
    effect: 'Audit'
  }
  {
    displayName: 'Storage accounts should have infrastructure encryption'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/4733ea7b-a883-42fe-8cac-97454c2a9e4a'
    identity: 'None'
    scope: resourceGroupIds.management
    effect: 'Audit'
  }
]


var builtinPoliciesSub = [
  {
    assignmentName: 'Deploy Guest Configuration extension with managed identity'
    policyDefinitionId: '/providers/Microsoft.Authorization/policySetDefinitions/12794019-7a00-42cf-95c2-882eed337cc8'
    identity: 'SystemAssigned'
    scope: subscription()

  }
]

module modPolicyAssignmentRg '../../ResourceModules/modules/authorization/policy-assignment/resource-group/main.bicep' = [for (builtinPolicy,i) in builtinPoliciesRg: {
  name: 'policyAssignRg_${i}'
  scope: resourceGroup(last(split(builtinPolicy.scope, '/'))!)
  params: {
    name: guid(builtinPolicy.policyDefinitionId,builtinPolicy.scope)
    policyDefinitionId: builtinPolicy.policyDefinitionId
    location: location
    identity: builtinPolicy.identity
    displayName: builtinPolicy.displayName
    parameters: !empty(builtinPolicy.effect) ? {
      effect: { value: builtinPolicy.effect
      }
    } : {}
  }
}]

module modRoleAssignmentsRg '../../ResourceModules/modules/authorization/role-assignment/resource-group/main.bicep' = [for (builtinPolicy,i) in builtinPoliciesRg: if ((builtinPolicy.identity != 'None')) {
  name: 'roleAssignRg_${i}'
  scope: resourceGroup(last(split(builtinPolicy.scope, '/'))!)
  params: {
    principalId: modPolicyAssignmentRg[i].outputs.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionIdOrName: '/providers/microsoft.authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
  }
}]

module modPolicyAssignmentSub '../../ResourceModules/modules/authorization/policy-assignment/subscription/main.bicep' = [for (builtinPolicy,i) in builtinPoliciesSub: {
  name: 'poAssignSub_${i}'
  scope: subscription()
  params: {
    name: guid(builtinPolicy.policyDefinitionId,subscription().id)
    policyDefinitionId: builtinPolicy.policyDefinitionId
    location: location
    identity: builtinPolicy.identity
    displayName: builtinPolicy.assignmentName
  }
}]

module modRoleAssignmentsSub '../../ResourceModules/modules/authorization/role-assignment/subscription/main.bicep' = [for (builtinPolicy,i) in builtinPoliciesSub: if ((builtinPolicy.identity != 'None')) {
  name: 'roleAssignSub_${i}'
  scope: subscription()
  params: {
    principalId: modPolicyAssignmentRg[i].outputs.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionIdOrName: '/providers/microsoft.authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
    location: location
  }
  
} ]
