// bastion.test.bicep

param location string = resourceGroup().location
param envName string = 'mod-bastion'

// Basic SKU

resource vnetBasic 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: 'vnet-${envName}-basic'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
    ]
  }
}

module bastionBasic '../bastion.bicep' = {
  name: 'deploy-bastion-basic'
  params: {
    location: location
    nameSuffix: 'basic'
    vnetName: vnetBasic.name
    skuName: 'Basic'
  }
}

// Standard SKU

resource vnetStandard 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: 'vnet-${envName}-std'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
    ]
  }
}

module bastionStandard '../bastion.bicep' = {
  name: 'deploy-bastion-standard'
  params: {
    location: location
    nameSuffix: 'std'
    vnetName: vnetStandard.name
    skuName: 'Standard'
  }
}
