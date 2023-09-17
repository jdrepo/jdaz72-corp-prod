
targetScope = 'subscription'

@description('Optional. Location for the Platform landing zone')
param location string = 'westeurope'

@description('Optional. Timestamp for running the deplyment')
param dateTime string = '${utcNow('G')} UTC'

@description('Optional. The type of environment')
@allowed([
  'prod'
  'qa'
  'dev'
])
param environment string = 'dev'



var projectId = '001-jdaz72-corp'
var rgIdentityName = !empty(projectId) ? 'rg-identity-${projectId}-${environment}' : 'rg-identity-${environment}'
var rgManagementName = !empty(projectId) ? 'rg-management-${projectId}-${environment}' : 'rg-management-${environment}'
var rgConnectivityName = !empty(projectId) ? 'rg-connectivity-${projectId}-${environment}' : 'rg-connectivity-${environment}'


var tags = {
  environment: environment
  project: projectId
  modified: dateTime
}

module modLocCode 'locCode.bicep' = {
  name: 'locCode'
  scope: resourceGroup(rgManagementName)
  params: {
    location: modRgManagement.outputs.location
  }
}
var locCode = modLocCode.outputs.locCode

var _dep = deployment().name



module modRgIdentity '../../ResourceModules/modules/resources/resource-group/main.bicep' = {
  name: '${_dep}-${rgIdentityName}'
  scope: subscription()
  params: {
    name: rgIdentityName
    location: location
    tags: tags
  }
}


module modRgConnectivity '../../ResourceModules/modules/resources/resource-group/main.bicep' = {
  name: '${_dep}-rg-connectivity-${projectId}-${environment}'
  scope: subscription()
  params: {
    name: 'rg-connectivity-${projectId}-${environment}'
    location: location
    tags: tags
  }
}

module modRgManagement '../../ResourceModules/modules/resources/resource-group/main.bicep' = {
  name: '${_dep}-rg-management-${projectId}-${environment}'
  scope: subscription()
  params: {
    name: 'rg-management-${projectId}-${environment}'
    location: location
    tags: tags
  }
}


// Policy assignment



module modPol 'policies.bicep' = {
  name: '${_dep}-Pol'
  scope: subscription()
  params: {
    
  }
}

// Log Analytics Workspace


module mod_laws_shared001 '../../ResourceModules/modules/operational-insights/workspace/main.bicep' = {
  name: '${_dep}-laws-001-${environment}'
  scope: resourceGroup(rgManagementName)
  params: {
    name: 'laws-001-${locCode}-${environment}'
    location: modRgManagement.outputs.location
    tags: tags

  }
}

// KeyVault deployment

module mod_KeyVault001 'keyVault.bicep' = {
  name: '${_dep}-keyVault-001-${environment}'
  scope: resourceGroup(rgManagementName)
  params: {
    environment: environment
    location: modRgManagement.outputs.location
    tags: tags
  }
}

resource res_KeyVault001 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: mod_KeyVault001.outputs.name
  scope: resourceGroup(rgManagementName)
}

/// CMK support for storage account encryption

// Create user assigned managed Identity for Storage Accounts

module mod_managedIdentityStorageAccounts '../../ResourceModules/modules/managed-identity/user-assigned-identity/main.bicep' = {
  name: '${_dep}-managedIdentityStorageAccounts'
  scope: resourceGroup(rgManagementName)
  params: {
    name: 'midu-sa-${locCode}-001-${environment}'
    location: location
  }
}



// Assign 'Key Vault Crypto Service Encryption User Role' to user assigned managed Identity for Storage Accounts
module mod_roleAssignKeyVault001CmkSa '../../ResourceModules/modules/key-vault/vault/.bicep/nested_roleAssignments.bicep' = {
  name: 'dep-roleAssignKeyVault001CmkSa'
  scope: resourceGroup(rgManagementName)
  params: {
    resourceId: mod_KeyVault001.outputs.resourceId
    principalIds: [
       mod_managedIdentityStorageAccounts.outputs.principalId
    ]
    roleDefinitionIdOrName: 'Key Vault Crypto Service Encryption User'
    principalType: 'ServicePrincipal'
  }
}

// Create cmk key for sa
module mod_keySaCmk '../../ResourceModules/modules/key-vault/vault/key/main.bicep' = {
  name: '${_dep}-mod_keySaCmk'
  scope: resourceGroup(rgManagementName)
  params: {
    name: 'cmk-sa'
    keyVaultName: mod_KeyVault001.outputs.name
    keySize: 4096
    kty: 'RSA'
    rotationPolicy: {
      attributes: {
          expiryTime: 'P2Y'
      }
      lifetimeActions: [
          {
              trigger: {
                  timeBeforeExpiry: 'P2M'
              }
              action: {
                  type: 'Rotate'
              }
          }
          {
              trigger: {
                  timeBeforeExpiry: 'P30D'
              }
              action: {
                  type: 'Notify'
              }
          }
      ]
  }
  }
}


// Deploy vmpassword secret to KeyVault as User-assigned Managed Identity for KeyVault soft recovery

module mod_setSecretIfNotExistsScript '../../ResourceModules/modules/resources/deployment-script/main.bicep' = {
  name: '${_dep}-setSecretIfNotExistsScript'
  scope: resourceGroup(rgManagementName)
  params: {
    tags: tags
    location: modRgManagement.outputs.location
    name: 'setSecretIfNotExistsScript_${uniqueString('vmpassword')}'
    kind: 'AzurePowerShell'
    retentionInterval: 'PT1H'
    cleanupPreference: 'Always'
    userAssignedIdentities: {
      '${mod_KeyVault001.outputs.SecretDeployIdentityId}' : {}
    }
    environmentVariables: {
      secureList: [
        {
          name: 'KV_NAME'
          value: mod_KeyVault001.outputs.name
        }
        {
          name: 'RG_NAME'
          value: rgManagementName
        }
        {
          name: 'SECRET_NAME'
          value: 'vmpassword'
        }
      ]
    }
    scriptContent: loadTextContent('kv-add-secret.ps1')
  }
}


// Maintenance Configuration for windows VM Guest patching - Definition Updates

module mod_timecalcSchedule1 'timecalc.bicep' = {
  name: '${_dep}-timecalc_schedule1'
  scope: resourceGroup(rgManagementName)
  params: {
    DeploymentStartTime: '22:00'
  }
}

module mod_windowsVmPatchConfigDefs 'ts/modules:maintenance.maintenance-configuration:latest' = {
  name: '${_dep}-windowsVmPatchConfigDefinition'
  scope: resourceGroup(rgManagementName)
  params: {
    name: 'maintcfg-${locCode}-winguest-patch-001'
    maintenanceScope: 'InGuestPatch'
    tags: tags
    location: location
    maintenanceWindow: {
      startDateTime: mod_timecalcSchedule1.outputs.scheduleStartMaintenance
      duration: '01:30'
      timeZone: 'W. Europe Standard Time'
      expirationDateTime: null
      recurEvery: '6Hour'
    }
    extensionProperties: {
      InGuestPatchMode: 'User'
    }
    installPatches: {
      linuxParameters: {
        classificationsToInclude: null
        packageNameMasksToExclude: null
        packageNameMasksToInclude: null
      }
      rebootSetting: 'Never'
      windowsParameters: {
        classificationsToInclude: [
          'Definition'
        ]
        kbNumbersToExclude: null
        kbNumbersToInclude: null
      }
    }

  }
}

module mod_polAssignPatchConfigDef '../../ResourceModules/modules/authorization/policy-assignment/resource-group/main.bicep' = {
  name: '${_dep}-polAssignPatchConfigDef'
  scope: resourceGroup(rgIdentityName)
  params: {
    name: guid('/providers/Microsoft.Authorization/policyDefinitions/ba0df93e-e4ac-479a-aac2-134bbae39a1a',rgIdentityName)
    displayName: 'Deploy Definition Updates using Update Management Center'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/ba0df93e-e4ac-479a-aac2-134bbae39a1a'
    identity: 'SystemAssigned'
    location: location
    parameters: {
      maintenanceConfigurationResourceId: { 
        value: mod_windowsVmPatchConfigDefs.outputs.resourceId 
      }
    }
  }
}

module mod_roleAssignPatchConfigDef1 '../../ResourceModules/modules/authorization/role-assignment/resource-group/main.bicep' =  {
  name: '${_dep}-roleAssignPatchConfigDef1'
  scope: resourceGroup(rgIdentityName)
  params: {
    principalId: mod_polAssignPatchConfigDef.outputs.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionIdOrName: '/providers/microsoft.authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'  // Contributor
  }
}

module mod_roleAssignPatchConfigDef2 '../../ResourceModules/modules/authorization/role-assignment/resource-group/main.bicep' =  {
  name: '${_dep}-roleAssignPatchConfigDef2'
  scope: resourceGroup(rgManagementName)
  params: {
    principalId: mod_polAssignPatchConfigDef.outputs.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionIdOrName: '/providers/microsoft.authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7'  // Reader
  }
}


// Maintenance Configuration for windows VM Guest patching - Critical and Security Updates

module mod_timecalcSchedule2 'timecalc.bicep' = {
  name: '${_dep}-timecalc_schedule2'
  scope: resourceGroup(rgManagementName)
  params: {
    DeploymentStartTime: '01:00'
  }
}

module mod_windowsVmPatchConfigCritSec 'br/modules:maintenance.maintenance-configuration:latest' = {
  name: '${_dep}-windowsVmPatchConfigCritSec'
  scope: resourceGroup(rgManagementName)
  params: {
    name: 'maintcfg-${locCode}-winguest-patch-002'
    maintenanceScope: 'InGuestPatch'
    tags: tags
    location: location
    maintenanceWindow: {
      startDateTime: mod_timecalcSchedule2.outputs.scheduleStartMaintenance
      duration: '01:30'
      timeZone: 'W. Europe Standard Time'
      expirationDateTime: null
      recurEvery: '1Day'
    }
    extensionProperties: {
      InGuestPatchMode: 'User'
    }
    installPatches: {
      linuxParameters: {
        classificationsToInclude: null
        packageNameMasksToExclude: null
        packageNameMasksToInclude: null
      }
      rebootSetting: 'IfRequired'
      windowsParameters: {
        classificationsToInclude: [
          'Critical'
          'Security'
        ]
        kbNumbersToExclude: null
        kbNumbersToInclude: null
      }
    }

  }
}

module mod_polAssignPatchCritSec '../../ResourceModules/modules/authorization/policy-assignment/resource-group/main.bicep' = {
  name: '${_dep}-polAssignPatchCritSec'
  scope: resourceGroup(rgIdentityName)
  params: {
    name: guid('/providers/Microsoft.Authorization/policyDefinitions/ba0df93e-e4ac-479a-aac2-134bbae39a1a',rgIdentityName)
    displayName: 'Deploy Critical and Security Updates using Update Management Center'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/ba0df93e-e4ac-479a-aac2-134bbae39a1a'
    identity: 'SystemAssigned'
    location: location
    parameters: {
      maintenanceConfigurationResourceId: { 
        value: mod_windowsVmPatchConfigCritSec.outputs.resourceId 
      }
    }
  }
}

module mod_roleAssignPatchCritSec1 '../../ResourceModules/modules/authorization/role-assignment/resource-group/main.bicep' =  {
  name: '${_dep}-roleAssignPatchCritSec1'
  scope: resourceGroup(rgIdentityName)
  params: {
    principalId: mod_polAssignPatchCritSec.outputs.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionIdOrName: '/providers/microsoft.authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'    // Contributor
  }
}

module mod_roleAssignPatchCritSec2 '../../ResourceModules/modules/authorization/role-assignment/resource-group/main.bicep' =  {
  name: '${_dep}-roleAssignPatchCritSec2'
  scope: resourceGroup(rgManagementName)
  params: {
    principalId: mod_polAssignPatchCritSec.outputs.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionIdOrName: '/providers/microsoft.authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7'  // Reader
    resourceGroupName: mod_windowsVmPatchConfigCritSec.outputs.resourceGroupName
  }
}



// Active Directory Deployment

module mod_activeDirectory 'activeDirectory.bicep' = {
  name: '${_dep}-activeDirectory-${environment}'
  dependsOn: [modRgIdentity]
  scope: resourceGroup(rgIdentityName)
  params: {
    tags: tags
    adminPassword: res_KeyVault001.getSecret('vmpassword')
    location: modRgIdentity.outputs.location
    environment: environment
  }
}

/// Guest Config Policies

// Create storage account

module mod_storageAccountGuestConfig '../../ResourceModules/modules/storage/storage-account/main.bicep' = {
  name: '${_dep}-storageAccountGuestConfig-${environment}'
  scope: resourceGroup(subscription().subscriptionId,rgManagementName)
  params: {
    name: 'sa${locCode}gc${take(uniqueString(modRgManagement.outputs.resourceId),6)}'
    location: location
    skuName: 'Standard_LRS'
    allowBlobPublicAccess: true
    userAssignedIdentities: {
      '${mod_managedIdentityStorageAccounts.outputs.resourceId}' : {}
    }
    cMKKeyVaultResourceId: mod_KeyVault001.outputs.resourceId
    cMKKeyName: mod_keySaCmk.outputs.name
    cMKUserAssignedIdentityResourceId: mod_managedIdentityStorageAccounts.outputs.resourceId
    requireInfrastructureEncryption: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: [
        {
          action: 'Allow'
          id: '${mod_activeDirectory.outputs.virtualNetworkId}/subnets/subnet001'
        }
      ]
      ipRules: [
        {
          action: 'Allow'
          value: '195.243.97.130'
        }
      ]
    }
    blobServices: {
      containers: [
        {
          name: 'machine-configuration'
          publicAccess: 'Blob'
        }
      ]
    }
  }
}

