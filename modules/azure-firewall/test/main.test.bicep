param location string = resourceGroup().location
param envName string = 'afw-module-test'
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
  name: 'AzureFirewallSubnet'
  properties: {
    addressPrefix: '10.0.0.0/24'
  }
}

module afw '../azure-firewall.bicep' = {
  dependsOn: [
    afwSubnet
  ]
  name: 'deploy-${envName}'
  params:{
    location: location
    afwNameSuffix: envName
    vnetName: vnetName
    numPublicIpAddresses: 2
  }
}
