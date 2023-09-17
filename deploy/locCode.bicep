@description('Required. Location')
param location string

// Object containing a mapping for location / region code
var regionCodes = {
  germanywestcentral: 'gwc'
  westeurope: 'weu'
  northeurope: 'neu'
}

output locCode string = regionCodes[location]
