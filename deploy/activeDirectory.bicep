targetScope = 'resourceGroup'

@description('Optional. Location for the solution')
param location string = 'westeurope'

@description('Optional. The type of environment')
@allowed([
  'prod'
  'qa'
  'dev'
])
param environment string = 'prod'

@description('Optional. Resource tags')
param tags object = {}


@description('Optional. The name of the Administrator of the new VM and Domain')
param adminUsername string = 'azadmin'

@description('Required. The password for the Administrator account of the new VM and Domain')
@secure()
param adminPassword string

@description('Optional. The FQDN of the AD Domain created ')
param domainName string = 'contoso.local'

@description('Optional. Size of the VM for the Domain Controller')
param vmSize string = 'Standard_B2s'

@description('Optional. Adress range for Virtual Network')
param vNetAddressRange1 array = ['10.99.0.0/16']

@description('Optional. Adress range for Domain Controller Subnet')
param adSubnet1 string = '10.99.1.0/24'

var _dep = deployment().name

module mod_vnet001 '../../ResourceModules/modules/network/virtual-network/main.bicep' = {
 name: '${_dep}-vnet-001-${environment}'
 params: {
  location: location
  name: 'vnet-001-${environment}'
  addressPrefixes: vNetAddressRange1
  subnets: [
    {
      name: 'subnet001'
      addressPrefix: adSubnet1
    }
  ]
  
 }
}




