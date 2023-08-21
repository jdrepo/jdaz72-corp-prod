
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
param environment string = 'prod'

var projectId = '001-jdaz72-corp'
var rgIdentityName = !empty(projectId) ? 'rg-identity-${projectId}-${environment}' : 'rg-identity-${environment}'
var rgManagementName = !empty(projectId) ? 'rg-management-${projectId}-${environment}' : 'rg-management-${environment}'
var rgConnectivityName = !empty(projectId) ? 'rg-connectivity-${projectId}-${environment}' : 'rg-connectivity-${environment}'


var tags = {
  environment: environment
  project: projectId
  modified: dateTime
}

var _dep = deployment().name

module modRgIdentity '../../ResourceModules/modules/resources/resource-groups/main.bicep' = {
  name: '${_dep}-${rgIdentityName}'
  scope: subscription()
  params: {
    name: rgIdentityName
    location: location
    tags: tags
  }
}


module modRgConnectivity '../../ResourceModules/modules/resources/resource-groups/main.bicep' = {
  name: '${_dep}-rg-connectivity-${projectId}-${environment}'
  scope: subscription()
  params: {
    name: 'rg-connectivity-${projectId}-${environment}'
    location: location
    tags: tags
  }
}

module modRgManagement '../../ResourceModules/modules/resources/resource-groups/main.bicep' = {
  name: '${_dep}-rg-management-${projectId}-${environment}'
  scope: subscription()
  params: {
    name: 'rg-management-${projectId}-${environment}'
    location: location
    tags: tags
  }
}


module mod_laws_shared001 '../../ResourceModules/modules/operational-insights/workspaces/main.bicep' = {
  name: '${_dep}-laws-001-${environment}'
  scope: resourceGroup(rgManagementName)
  params: {
    name: 'laws-001-${environment}'
    location: modRgManagement.outputs.location
    tags: tags

  }
}


// Active Directory Deployment

module mod_activeDirectory 'activeDirectory.bicep' = {
  name: '${_dep}-activeDirectory-${environment}'
  dependsOn: [modRgIdentity]
  scope: resourceGroup(rgIdentityName)
  params: {
    tags: tags
    adminPassword: 'ChangeMe1!'
    location: modRgIdentity.outputs.location
  }
}
