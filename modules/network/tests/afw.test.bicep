param location string = resourceGroup().location
param envName string = 'mod-azfw'

resource vnet 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: 'vnet-${envName}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.0.0.0/24'
          routeTable: {
            id: rt.id
          }
        }
      }
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
    ]
  }
}

resource rt 'Microsoft.Network/routeTables@2022-09-01' = {
  name: 'rt-${envName}'
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'internet-to-afw'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopIpAddress: '10.0.1.4'
          nextHopType: 'VirtualAppliance'
        }
      }
    ]
  }
}

module afw '../afw.bicep' = {
  name: 'deploy-afw'
  params: {
    location: location
    nameSuffix: envName
    vnetName: vnet.name
    numPublicIpAddresses: 2
    enableFirewallPolicy: true
  }
}
