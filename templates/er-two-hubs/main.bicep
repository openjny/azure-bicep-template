@description('location')
param location string = resourceGroup().location

@description('Source IP address from which you access to VMs')
param sourceAddressPrefix string

@description('VM username')
param adminUsername string = 'azureuser'

@description('VM password')
@secure()
param adminPassword string

// ----------------------------------------------------------------------------
// Variables
// ----------------------------------------------------------------------------

var securityRules = [
  {
    name: 'AllowInboundFromSafePlace'
    properties: {
      protocol: '*'
      sourceAddressPrefix: sourceAddressPrefix
      sourcePortRange: '*'
      destinationAddressPrefix: '*'
      destinationPortRange: '*'
      access: 'Allow'
      priority: 100
      direction: 'Inbound'
    }
  }
]

var unprotectedSubnets = [
  'AzureBastionSubnet'
  'GatewaySubnet'
  'RouteServerSubnet'
  'AzureFirewallSubnet'
  'AzureFirewallManagementSubnet'
]

var hub1Config = {
  name: 'hub1'
  addressSpace: '10.1.0.0/16'
  subnets: [
    {
      name: 'default'
      addressPrefix: '10.1.0.0/24'
    }
    {
      name: 'AzureFirewallSubnet'
      addressPrefix: '10.1.100.0/24'
    }
    {
      name: 'RouteServerSubnet'
      addressPrefix: '10.1.254.0/24'
    }
    {
      name: 'GatewaySubnet'
      addressPrefix: '10.1.255.0/24'
    }
  ]
}

var hub1SpokeConfig = [
  {
    name: 'hub1-s1'
    addressSpace: '10.100.1.0/24'
    subnets: [
      {
        name: 'default'
        addressPrefix: '10.100.1.0/24'
      }
    ]
  }
  {
    name: 'hub1-s2'
    addressSpace: '10.100.2.0/24'
    subnets: [
      {
        name: 'default'
        addressPrefix: '10.100.2.0/24'
      }
    ]
  }
]

// ----------------------------------------------------------------------------
// Resources - Azure Hub Spoke
// ----------------------------------------------------------------------------

resource nsg 'Microsoft.Network/networkSecurityGroups@2022-09-01' = {
  name: 'nsg-subnet'
  location: location
  properties: {
    securityRules: empty(sourceAddressPrefix) ? null : securityRules
  }
}

resource hub1 'Microsoft.Network/virtualNetworks@2022-09-01' = {
  location: location
  name: 'vnet-${hub1Config.name}'
  properties: {
    addressSpace: {
      addressPrefixes: [
        hub1Config.addressSpace
      ]
    }
    subnets: [for (subnet, i) in hub1Config.subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
        networkSecurityGroup: contains(unprotectedSubnets, subnet.name) ? null : {
          id: nsg.id
        }
      }
    }]
  }
}

resource hub1Spokes 'Microsoft.Network/virtualNetworks@2022-09-01' = [for (spoke, i) in hub1SpokeConfig: {
  location: location
  name: 'vnet-${spoke.name}'
  properties: {
    addressSpace: {
      addressPrefixes: [
        spoke.addressSpace
      ]
    }
    subnets: [for (subnet, i) in spoke.subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
        networkSecurityGroup: contains(unprotectedSubnets, subnet.name) ? null : {
          id: nsg.id
        }
      }
    }]
  }
}]

module hub1SpokeVms '../../modules/compute/vm.bicep' = [for (spoke, i) in hub1SpokeConfig: {
  dependsOn: [
    hub1Spokes
  ]
  name: 'deploy-vm-${spoke.name}'
  params: {
    location: location
    nameSuffix: spoke.name
    vnetName: hub1Spokes[i].name
    subnetName: 'default'
    deployPublicIp: true
    osType: 'Linux'
    publicIpSku: 'Standard'
    vmSize: 'Standard_D2_v5'
    adminUsername: adminUsername
    adminPasswordOrKey: adminPassword
    authenticationType: 'password'
  }
}]

module hub1Fw '../../modules/network/afw.bicep' = {
  name: 'deploy-hub1-fw'
  params: {
    location: location
    vnetName: hub1.name
    nameSuffix: hub1Config.name
    tier: 'Basic'
  }
}

// Hub 2 - Spokes

var hub2Config = {
  name: 'hub2'
  addressSpace: '10.2.0.0/16'
  subnets: [
    {
      name: 'default'
      addressPrefix: '10.2.0.0/24'
    }
    {
      name: 'AzureFirewallSubnet'
      addressPrefix: '10.2.100.0/24'
    }
    {
      name: 'RouteServerSubnet'
      addressPrefix: '10.2.254.0/24'
    }
    {
      name: 'GatewaySubnet'
      addressPrefix: '10.2.255.0/24'
    }
  ]
}

var hub2SpokeConfig = [
  {
    name: 'hub2-s1'
    addressSpace: '10.200.1.0/24'
    subnets: [
      {
        name: 'default'
        addressPrefix: '10.200.1.0/24'
      }
    ]
  }
]

resource hub2 'Microsoft.Network/virtualNetworks@2022-09-01' = {
  location: location
  name: 'vnet-${hub2Config.name}'
  properties: {
    addressSpace: {
      addressPrefixes: [
        hub2Config.addressSpace
      ]
    }
    subnets: [for (subnet, i) in hub2Config.subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
        networkSecurityGroup: contains(unprotectedSubnets, subnet.name) ? null : {
          id: nsg.id
        }
      }
    }]
  }
}

resource hub2Spokes 'Microsoft.Network/virtualNetworks@2022-09-01' = [for (spoke, i) in hub2SpokeConfig: {
  location: location
  name: 'vnet-${spoke.name}'
  properties: {
    addressSpace: {
      addressPrefixes: [
        spoke.addressSpace
      ]
    }
    subnets: [for (subnet, i) in spoke.subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
        networkSecurityGroup: contains(unprotectedSubnets, subnet.name) ? null : {
          id: nsg.id
        }
      }
    }]
  }
}]

module hub2SpokeVms '../../modules/compute/vm.bicep' = [for (spoke, i) in hub2SpokeConfig: {
  dependsOn: [
    hub1Spokes
  ]
  name: 'deploy-vm-${spoke.name}'
  params: {
    location: location
    nameSuffix: spoke.name
    vnetName: hub2Spokes[i].name
    subnetName: 'default'
    deployPublicIp: true
    osType: 'Linux'
    publicIpSku: 'Standard'
    vmSize: 'Standard_D2_v5'
    adminUsername: adminUsername
    adminPasswordOrKey: adminPassword
    authenticationType: 'password'
  }
}]

module hub2Fw '../../modules/network/afw.bicep' = {
  name: 'deploy-hub2-fw'
  params: {
    location: location
    vnetName: hub2.name
    nameSuffix: hub2Config.name
    tier: 'Basic'
  }
}
