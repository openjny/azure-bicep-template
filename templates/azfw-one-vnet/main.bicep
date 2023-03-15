@description('location')
param location string = resourceGroup().location

@description('Source IP address from which you access to VMs')
param sourceAddressPrefix string

@description('VM username')
param adminUsername string = 'azureuser'

@description('VM password')
@secure()
param adminPassword string

@description('Environment name used for suffix')
param envName string = 'azfw1vnet'

// ----------------------------------------------------------------------------
// Variables
// ----------------------------------------------------------------------------

var tags = {
  env: envName
}

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

var vnetConfig = {
  addressSpace: '10.0.0.0/16'
  subnets: [
    {
      name: 'default'
      addressPrefix: '10.0.0.0/24'
    }
    {
      name: 'AzureFirewallSubnet'
      addressPrefix: '10.0.1.0/24'
    }
    {
      name: 'AzureBastionSubnet'
      addressPrefix: '10.0.2.0/24'
    }
  ]
}

var afwPrivateIp = '10.0.1.4'

// ----------------------------------------------------------------------------
// Resources
// ----------------------------------------------------------------------------

resource subnetNsg 'Microsoft.Network/networkSecurityGroups@2022-09-01' = {
  name: 'nsg-subnet'
  location: location
  tags: tags
  properties: {
    securityRules: empty(sourceAddressPrefix) ? null : securityRules
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2022-09-01' = {
  name: 'vnet-${envName}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetConfig.addressSpace
      ]
    }
    subnets: [for (subnet, i) in vnetConfig.subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
        networkSecurityGroup: contains(unprotectedSubnets, subnet.name) ? null : {
          id: subnetNsg.id
        }
        routeTable: subnet.name != 'default' ? null : {
          id: rt.id
        }
      }
    }]
  }
}

resource rt 'Microsoft.Network/routeTables@2022-09-01' = {
  name: 'rt-default'
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'internet-to-afw'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopIpAddress: afwPrivateIp
          nextHopType: 'VirtualAppliance'
        }
      }
    ]
  }
}

module vm_win '../../modules/compute/vm.bicep' = {
  name: 'deploy-vm-${envName}-win'
  params: {
    location: location
    nameSuffix: '${envName}-win'
    vnetName: vnet.name
    subnetName: 'default'
    deployPublicIp: false
    osType: 'Windows'
    vmSize: 'Standard_D4_v4'
    adminUsername: adminUsername
    adminPasswordOrKey: adminPassword
    authenticationType: 'password'
  }
}

module vm_linux '../../modules/compute/vm.bicep' = {
  name: 'deploy-vm-${envName}-linux'
  params: {
    location: location
    nameSuffix: '${envName}-linux'
    vnetName: vnet.name
    subnetName: 'default'
    deployPublicIp: false
    osType: 'Linux'
    vmSize: 'Standard_B2s'
    adminUsername: adminUsername
    adminPasswordOrKey: adminPassword
    authenticationType: 'password'
  }
}

module bastion '../../modules/network/bastion.bicep' = {
  name: 'deploy-bastion'
  params: {
    location: location
    nameSuffix: envName
    vnetName: vnet.name
    skuName: 'Standard'
  }
}

module afw '../../modules/network/afw.bicep' = {
  name: 'deploy-afw'
  params: {
    location: location
    nameSuffix: envName
    vnetName: vnet.name
    tier: 'Premium'
    numPublicIpAddresses: 1
    allowFromRFC1918: false
  }
}
