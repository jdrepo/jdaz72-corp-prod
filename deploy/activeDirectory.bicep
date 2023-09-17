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


@description('Optional. The name of the Administrator of the new VM and Domain')
param adminUsername string = 'azadmin'

@description('Required. The password for the Administrator account of the new VM and Domain')
@secure()
param adminPassword string

@description('Optional. The FQDN of the AD Domain created ')
param domainName string = 'contoso.local'


@description('Optional. Adress range for Virtual Network')
param vNetAddressRange1 array = ['10.99.0.0/16']

@description('Optional. Adress range for Domain Controller Subnet')
param adSubnetRange string = '10.99.1.0/24'

var _dep = deployment().name
var locCode = modLocCode.outputs.locCode
var virtualNetwork1Name = 'vnet-001-${locCode}-${environment}'
var adSubnetName = 'subnet001'
var adSubnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetwork1Name, adSubnetName)
var vmDc01Size = 'Standard_B2s'
var vmDc01Ip = '10.99.1.4'

module modLocCode 'locCode.bicep' = {
  name: 'locCode'
  params: {
    location: location
  }
}


module modVnet001 '../../ResourceModules/modules/network/virtual-network/main.bicep' = {
 name: '${_dep}-Vnet001-${environment}'
 params: {
  location: location
  name: virtualNetwork1Name
  addressPrefixes: vNetAddressRange1
  subnets: [
    {
      name: adSubnetName
      addressPrefix: adSubnetRange
      networkSecurityGroupId: modNsgAdSubnet.outputs.resourceId
      serviceEndpoints: [
        {
        service: 'Microsoft.Storage'
        //service: 'Microsoft.KeyVault'
        }
        {
          service: 'Microsoft.KeyVault'
        }

      ]
    }
  ]
  
 }
}

module modNsgAdSubnet '../../ResourceModules/modules/network/network-security-group/main.bicep' = {
  name: '${_dep}-nsgAdSubnet'
  params: {
    name: 'nsg-ad-subnet-${locCode}-${environment}'
    location: location
    securityRules: [
      {
        name: 'RDP-access'
        properties: {
          access: 'Allow'
          description: 'RDP access internet'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
          direction: 'Inbound'
          priority: 100
          protocol: '*'
          sourceAddressPrefixes: [
            '195.243.97.130/32'
            '77.21.152.151/32'
          ]
          sourcePortRange: '*'
        }
      }
    ]
  }
}


module modVmDc001 '../../ResourceModules/modules/compute/virtual-machine/main.bicep' = {
  name: '${_dep}-VmDc001-${environment}'
  params: {
    location: location
    tags: tags
    name: 'vm-dc01-${environment}'
    adminUsername: adminUsername
    adminPassword: adminPassword
    vmSize: vmDc01Size
    systemAssignedIdentity: true
    imageReference: {
      offer: 'WindowsServer'
      publisher: 'MicrosoftWindowsServer'
      sku: '2022-datacenter-azure-edition-smalldisk'
      version: 'latest'
    }
    nicConfigurations: [
      {
        tags: tags
        enableAcceleratedNetworking: false
        nicSuffix: '-nic-01'
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: adSubnetRef
            privateIPAllocationMethod: 'Static'
            privateIPAddress: vmDc01Ip
            pipConfiguration: {
              publicIPNameSuffix: '-pip-01'
            }
            publicIPAllocationMethod: 'Static'
          }
        ]
      }
    ]
    osType: 'Windows'
    osDisk: {
      createOption: 'fromImage'
      diskSizeGB: '31'
      managedDisk: {
        storageAccountType: 'Standard_LRS'
      }
    }
    dataDisks: [
      {
        caching: 'None'
        createOption: 'Empty'
        diskSizeGB: '8'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    ]
  }

    
    
}

output virtualNetworkId string = modVnet001.outputs.resourceId
output virtualNetworkSubnetIds array = modVnet001.outputs.subnetResourceIds
output virtualNetworkNames array = modVnet001.outputs.subnetNames




