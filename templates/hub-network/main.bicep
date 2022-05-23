@description('On-prem location')
param location string = resourceGroup().location

@description('Network environment name')
param envName string = 'hub'

@description('Network address for class B private network')
param baseNetworkAddress string = '10.0'

@description('Source IP addresses to access VMs')
param sourceAddressPrefix string

@description('VM username')
param adminUsername string

@description('VM Password')
@secure()
param adminPassword string

@description('If true, VPN Gateway will be deployed')
param deployVpnGw bool

@description('If true, Azure Firewall')
param deployAzureFirewall bool

// ----------------------------------------------------------------------------
// Variables
// ----------------------------------------------------------------------------

var vnetName = 'vnet-${envName}'
var addressPrefix = '${baseNetworkAddress}.0.0/16'
var subnets = [
  {
    name: 'snet-default'
    addressPrefix: '${baseNetworkAddress}.0.0/24'
  }
  {
    name: 'snet-pe'
    addressPrefix: '${baseNetworkAddress}.1.0/24'
  }
  {
    name: 'snet-nva'
    addressPrefix: '${baseNetworkAddress}.2.0/24'
  }
  {
    name: 'AzureBastionSubnet'
    addressPrefix: '${baseNetworkAddress}.64.0/24'
  }
  {
    name: 'AzureFirewallSubnet'
    addressPrefix: '${baseNetworkAddress}.100.0/24'
  }
  {
    name: 'RouteServerSubnet'
    addressPrefix: '${baseNetworkAddress}.200.0/24'
  }
  {
    name: 'GatewaySubnet'
    addressPrefix: '${baseNetworkAddress}.255.0/24'
  }
]
var unprotectedSubnets = [
  'AzureFirewallSubnet'
  'AzureBastionSubnet'
  'RouteServerSubnet'
  'GatewaySubnet'
]

// ----------------------------------------------------------------------------
// Resources
// ----------------------------------------------------------------------------

resource vnet 'Microsoft.Network/virtualNetworks@2021-08-01' = {
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
          id: subnetnsg.id
        }
      }
    }]
  }
}

resource subnetnsg 'Microsoft.Network/networkSecurityGroups@2021-08-01' = {
  name: 'nsg-${envName}'
  location: location
  properties: {
    securityRules: [
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

module vmDefault '../../modules/compute-vm/compute-vm.bicep' = {
  dependsOn: [
    vnet
  ]
  name: 'deploy-vm-${envName}-default'
  params: {
    location: location
    vmName: '${envName}-default'
    vnetName: vnetName
    subnetName: 'default'
    deployPublicIp: true
    adminUsername: adminUsername
    adminPasswordOrKey: adminPassword
    authenticationType: 'password'
  }
}

module vpngw '../../modules/vpn-gateway/vpn-gateway.bicep' = if (deployVpnGw) {
  dependsOn: [
    vnet
  ]
  name: 'deploy-${envName}-vpngw'
  params: {
    location: location
    vnetName: vnetName
    gwNameSuffix: '${envName}-vpngw'
    enableBgp: true
    asn: 65515
  }
}


// ----------------------------------------------------------------------------
// Outputs
// ----------------------------------------------------------------------------

output vmDefaultHostname string = vmDefault.outputs.hostname
