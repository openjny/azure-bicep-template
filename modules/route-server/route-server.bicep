// route-server.bicep

@description('Region to deploy')
param location string = resourceGroup().location

@description('Route Server name (without the prefix "rs-")')
param rsNameSuffix string

@description('VNet name')
param vnetName string

@description('Enable branch-to-branch traffic')
param allowBranchToBranchTraffic bool = true

@description('BGP Peer connection settings')
@metadata({
  peerAsn: 'Peer ASN (int). Private ASN can be 64512-65534 except for {65515,65517,65518,65519,65520}'
  peerIp: 'Peer IP (string).'
})
param bgpConnections array = []

// ----------------------------------------------------------------------------
// Variables
// ----------------------------------------------------------------------------

var rsName = 'rs-${rsNameSuffix}'
var pipName = 'pip-${rsName}'

// ----------------------------------------------------------------------------
// Resources
// ----------------------------------------------------------------------------

resource pip 'Microsoft.Network/publicIPAddresses@2021-08-01' = {
  name: pipName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// refs:
// https://docs.microsoft.com/en-us/azure/route-server/overview
// https://docs.microsoft.com/en-us/azure/templates/microsoft.network/virtualhubs?tabs=bicep
// https://github.com/Azure/azure-quickstart-templates/blob/master/quickstarts/microsoft.network/route-server/main.bicep

resource rs 'Microsoft.Network/virtualHubs@2021-08-01' = {
  name: rsName
  location: location
  properties: {
    sku: 'Standard'
    allowBranchToBranchTraffic: allowBranchToBranchTraffic
  }
}

resource ipconfig 'Microsoft.Network/virtualHubs/ipConfigurations@2021-08-01' = {
  name: 'ipconfig1'
  parent: rs
  properties: {
    subnet:{
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'RouteServerSubnet')
    }
    publicIPAddress: {
      id: pip.id
    }
  }
}

@batchSize(1)
resource conn 'Microsoft.Network/virtualHubs/bgpConnections@2021-08-01' = [for (bgpConnection, i) in bgpConnections: {
  dependsOn: [
    ipconfig
  ]
  name: 'conn-${rsNameSuffix}-${i+1}'
  parent: rs
  properties: {
    peerAsn: bgpConnection.peerAsn
    peerIp: bgpConnection.peerIp
  }
}]

// ----------------------------------------------------------------------------
// Outputs
// ----------------------------------------------------------------------------
