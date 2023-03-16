// vnet-plain

@description('Region to deploy')
param location string = resourceGroup().location

@description('Environment name')
param envName string

@description('VNet address range up to the 2nd octet (e.g. 192.168, 172.16, 10.0, etc)')
param baseAddressSpace string = '192.168'

@description('Source IP address that VMs are accessed from')
param sourceAddressPrefix string = ''

@description('VM username')
param adminUsername string = 'azureuser'

@description('VM password')
@secure()
param adminPassword string

@description('Deploy VPN Gateway')
param deployVpnGateway bool = true

@description('Enable BGP on VPN Gatweay')
param enableBgp bool = true

@description('AS number of VPN Gateway')
param asn int = 65000

@description('Deploy Bastion Host')
param deployBastion bool = false

// Variables
// ----------------------------------------------------------------------------

var vnetName = 'vnet-${envName}'
var addressSpace = '${baseAddressSpace}.0.0/16'
var subnets = [
  {
    name: 'default'
    addressPrefix: '${baseAddressSpace}.0.0/24'
  }
  {
    name: 'AzureBastionSubnet'
    addressPrefix: '${baseAddressSpace}.100.0/24'
  }
  {
    name: 'GatewaySubnet'
    addressPrefix: '${baseAddressSpace}.101.0/24'
  }
  {
    name: 'RouteServerSubnet'
    addressPrefix: '${baseAddressSpace}.102.0/24'
  }
  {
    name: 'AzureFirewallSubnet'
    addressPrefix: '${baseAddressSpace}.200.0/24'
  }
  {
    name: 'AzureFirewallManagementSubnet'
    addressPrefix: '${baseAddressSpace}.201.0/24'
  }
]

var unprotectedSubnets = [
  'AzureBastionSubnet'
  'GatewaySubnet'
  'RouteServerSubnet'
  'AzureFirewallSubnet'
  'AzureFirewallManagementSubnet'
]

// ----------------------------------------------------------------------------
// Resources
// ----------------------------------------------------------------------------

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressSpace
      ]
    }
    subnets: [for (subnet, i) in subnets: {
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

resource nsg 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: 'nsg-${envName}'
  location: location
  properties: {
    securityRules: empty(sourceAddressPrefix) ? null : [
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
  }
}

module vm '../../modules/compute/vm.bicep' = {
  dependsOn: [
    vnet
  ]
  name: 'deploy-vm-${envName}'
  params: {
    location: location
    nameSuffix: envName
    vnetName: vnetName
    subnetName: 'default'
    deployPublicIp: true
    osType: 'Linux'
    adminUsername: adminUsername
    adminPasswordOrKey: adminPassword
    authenticationType: 'password'
  }
}

module vpngw '../../modules/network/vpngw.bicep' = if (deployVpnGateway) {
  dependsOn: [
    vnet
  ]
  name: 'deploy-vpngw'
  params: {
    location: location
    nameSuffix: envName
    vnetName: vnetName
    enableBgp: enableBgp
    asn: asn
  }
}

module bastion '../../modules/network/bastion.bicep' = if (deployBastion) {
  name: 'deploy-bastion'
  params: {
    location: location
    nameSuffix: envName
    vnetName: vnetName
    skuName: 'Standard'
  }
}

// ----------------------------------------------------------------------------
// Outputs
// ----------------------------------------------------------------------------
