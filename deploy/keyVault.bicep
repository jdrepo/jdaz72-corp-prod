//// KeyVault for common secrets and keys

// User-assigned Managed Identity for soft-deleted Key Vault check

targetScope = 'resourceGroup'

@description('Optional. Location for the solution')
param location string = 'westeurope'

@description('Optional. The type of environment')
@allowed([
  'prod'
  'qa'
  'dev'
])
param environment string = 'dev'

@description('Optional. Resource tags')
param tags object = {}

@description('Required. Service Principal ID for Storage Account Managed Identity')
//param managedIdentityStorageAccountsPrincipalId string

var _dep = deployment().name
var locCode = modLocCode.outputs.locCode

module modLocCode 'locCode.bicep' = {
  name: 'locCode'
  params: {
    location: location
  }
}


// User-assigned Managed Identity for access to KeyVault for secret deployment

module modSecretDeployIdentity '../../ResourceModules/modules/managed-identity/user-assigned-identity/main.bicep' = {
  name: '${_dep}-secretDeployIdentity'
  params: {
    location: location
    name: 'secretDeployIdentity'
    tags: tags
  }
}

// Create User-assigned Managed Identity for KeyVault soft recovery

module mod_recoverSoftDeletedKeyVaultIdentity '../../ResourceModules/modules/managed-identity/user-assigned-identity/main.bicep' = {
  name: 'recoverSoftDeletedKeyVaultIdentity'
  params: {
    name: 'recoverSoftDeletedKeyVaultIdentity'
    location: location
    tags: tags
  }
}

// Set RBAC permissions for User-assigned Managed Identity  for KeyVault soft recovery

module mod_rbac_recoverSoftDeletedKeyVaultIdentity '../../ResourceModules/modules/authorization/role-assignment/subscription/main.bicep' = {
  name: 'rbac_recoverSoftDeletedKeyVaultIdentity'
  scope: subscription()
  params: {
    location: location
    principalId: mod_recoverSoftDeletedKeyVaultIdentity.outputs.principalId
    roleDefinitionIdOrName: 'Key Vault Contributor'
    principalType: 'ServicePrincipal'
    description: 'Key Vault Contribitor role on subscription for soft-deleted Key Vault recovery'
  }
}

// Check for soft-deleted Key Vault and recover

module modRecoverSoftDeletedKeyVaultScript '../../ResourceModules/modules/resources/deployment-script/main.bicep' = {
  name: '${_dep}-recoverSoftDeletedKeyVaultScript'
  params: {
    tags: tags
    location: location
    name: 'recoverSoftDeletedKeyVaultScript_${uniqueString('kv-${locCode}-001-${environment}-${take(uniqueString(resourceGroup().name),6)}')}'
    kind: 'AzurePowerShell'
    retentionInterval: 'PT1H'
    cleanupPreference: 'Always'
    userAssignedIdentities: {
      '${mod_recoverSoftDeletedKeyVaultIdentity.outputs.resourceId}' : {}
    }
    environmentVariables: {
      secureList: [
        {
          name: 'KV_NAME'
          value: 'kv-${locCode}-001-${environment}-${take(uniqueString(resourceGroup().name),6)}'
        }
        {
          name: 'KV_LOCATION'
          value: location
        }
      ]
    }
    scriptContent: loadTextContent('kv-recover.ps1')
  }
}

// Create new Key Vault if not recovered or modify if recovered

module modKeyVault '../../ResourceModules/modules/key-vault/vault/main.bicep' = {
  name: '${_dep}-KeyVault'
  dependsOn: [modRecoverSoftDeletedKeyVaultScript]
  params: {
    tags: tags
    location: location
    name: 'kv-${locCode}-001-${environment}-${take(uniqueString(resourceGroup().name),6)}'
    enableVaultForDeployment: true
    enableRbacAuthorization: true
    enableVaultForDiskEncryption: true
    enableVaultForTemplateDeployment: true
    enablePurgeProtection: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    roleAssignments: [
      { 
        roleDefinitionIdOrName: 'Key Vault Secrets Officer'
        principalIds: [
          modSecretDeployIdentity.outputs.principalId
        ]
        principalType: 'ServicePrincipal'
        
      }
      { 
        roleDefinitionIdOrName: 'Key Vault Contributor'
        principalIds: [
          modSecretDeployIdentity.outputs.principalId
        ]
        principalType: 'ServicePrincipal' 
      }
    ]
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
}




// =========== //
// Outputs     //
// =========== //
@description('The resource ID of the key vault.')
output resourceId string = modKeyVault.outputs.resourceId


@description('The name of the resource group the key vault was created in.')
output resourceGroupName string = modKeyVault.outputs.resourceGroupName


@description('The name of the key vault.')
output name string = modKeyVault.outputs.name

@description('The URI of the key vault.')
output uri string = modKeyVault.outputs.uri

@description('The location the resource was deployed into.')
output location string = modKeyVault.outputs.location

@description('User-assigned Managed Identity for access to KeyVault.')
output SecretDeployIdentityId string = modSecretDeployIdentity.outputs.resourceId
