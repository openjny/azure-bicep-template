// rtserv.test.bicep

param location string = resourceGroup().location
param envName string = 'mod-rtserv'
param vnetName string = 'vnet-${envName}'

resource vnet 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'RouteServerSubnet'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
    ]
  }
}

module rtserv '../rtserv.bicep' = {
  dependsOn: [
    vnet
  ]
  name: 'deploy-rtserv'
  params: {
    location: location
    vnetName: vnetName
    nameSuffix: envName
    bgpConnections: [
      {
        peerAsn: 64512
        peerIp: '10.0.2.4'
      }
      {
        peerAsn: 64513
        peerIp: '10.0.3.4'
      }
      {
        peerAsn: 64514
        peerIp: '10.0.4.4'
      }
    ]
  }
}
