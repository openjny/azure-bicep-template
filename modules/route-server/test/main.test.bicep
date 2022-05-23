// route-server.test.bicep

param location string = resourceGroup().location
param envName string = 'module-route-server-test'
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

// resource snet 'Microsoft.Network/virtualNetworks/subnets@2020-06-01' = {
//   parent: vnet
//   name: 'RouteServerSubnet'
//   properties: {
//     addressPrefix: '10.0.0.0/24'
//   }
// }

module rs '../route-server.bicep' = {
  dependsOn: [
    vnet
  ]
  name: 'deploy-${envName}'
  params: {
    location: location
    vnetName: vnetName
    rsNameSuffix: envName
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
