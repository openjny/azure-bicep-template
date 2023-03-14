// vnet-plain

@description('location')
param location string = resourceGroup().location

@description('environment name')
param envName string

@description('ip address used in VNet up to the 2nd octet (e.g. 192.168, 172.16, 10.0, etc)')
param baseNetworkAddress string = '192.168'

@description('')
param sourceAddressPrefix string = ''

@description('VM username')
param adminUsername string = 'azureuser'

@description('VM password')
@secure()
param adminPassword string

@description('deploys VPN Gateway')
param deployVpnGateway bool = false

@description('enables BGP on VPN Gatweay')
param enableBgp bool = true

@description('AS number of VPN Gateway')
param asn int = 65000

// Variables
// ----------------------------------------------------------------------------

var vnetName = 'vnet-${envName}'
var addressPrefix = '${baseNetworkAddress}.0.0/16'
var subnets = [
  {
    name: 'default'
    addressPrefix: '${baseNetworkAddress}.0.0/24'
  }
  {
    name: 'AzureBastionSubnet'
    addressPrefix: '${baseNetworkAddress}.100.0/24'
  }
  {
    name: 'GatewaySubnet'
    addressPrefix: '${baseNetworkAddress}.101.0/24'
  }
  {
    name: 'RouteServerSubnet'
    addressPrefix: '${baseNetworkAddress}.102.0/24'
  }
  {
    name: 'AzureFirewallSubnet'
    addressPrefix: '${baseNetworkAddress}.200.0/24'
  }
  {
    name: 'AzureFirewallManagementSubnet'
    addressPrefix: '${baseNetworkAddress}.201.0/24'
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
        addressPrefix
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
  name: 'deploy-vm-${envName}-01'
  params: {
    location: location
    nameSuffix: '${envName}-01'
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

// ----------------------------------------------------------------------------
// Outputs
// ----------------------------------------------------------------------------

output vmHostname string = vm.outputs.hostname
