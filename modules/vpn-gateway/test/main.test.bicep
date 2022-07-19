param location string = resourceGroup().location
param envName string = 'module-vpn-gateway-test'
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

resource gateway_subnet 'Microsoft.Network/virtualNetworks/subnets@2020-06-01' = {
  parent: vnet
  name: 'GatewaySubnet'
  properties: {
    addressPrefix: '10.0.0.0/24'
  }
}

module vpn_gateway '../vpn-gateway.bicep' = {
  dependsOn: [
    gateway_subnet
  ]
  name: 'deploy-${envName}'
  params:{
    location: location
    vgwNameSuffix: envName
    vnetName: vnetName
    skuName: 'VpnGw1'
    vpnGatewayGeneration: 'Generation1'
    activeActive: true
    enableBgp: true
    asn: 65515
  }
}
