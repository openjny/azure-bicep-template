param location string = resourceGroup().location
param envName string = 'mod-vpngw'
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
  }
}

resource gwSubnet 'Microsoft.Network/virtualNetworks/subnets@2020-06-01' = {
  parent: vnet
  name: 'GatewaySubnet'
  properties: {
    addressPrefix: '10.0.0.0/24'
  }
}

module vpngw '../vpngw.bicep' = {
  dependsOn: [
    gwSubnet
  ]
  name: 'deploy-${envName}'
  params: {
    location: location
    nameSuffix: envName
    vnetName: vnetName
    skuName: 'VpnGw1'
    vpnGatewayGeneration: 'Generation1'
    activeActive: true
    enableBgp: true
    asn: 65515
  }
}
