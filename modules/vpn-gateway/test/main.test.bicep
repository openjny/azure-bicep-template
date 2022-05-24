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

resource afwSubnet 'Microsoft.Network/virtualNetworks/subnets@2020-06-01' = {
  parent: vnet
  name: 'GatewaySubnet'
  properties: {
    addressPrefix: '10.0.0.0/24'
  }
}

module afw '../vpn-gateway.bicep' = {
  dependsOn: [
    afwSubnet
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
