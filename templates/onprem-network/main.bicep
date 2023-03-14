@description('On-prem location')
param location string = resourceGroup().location

@description('On-prem name')
param onpremName string = 'onprem'

@description('Network address for class B private network')
param baseNetworkAddress string = '172.16'

@description('Source IP addresses to access VMs')
param sourceAddressPrefix string

@description('VM username')
param adminUsername string

@description('VM Password')
@secure()
param adminPassword string

@description('If true, VPN Gateway will be deployed')
param deployVpnGw bool

// ----------------------------------------------------------------------------
// Variables
// ----------------------------------------------------------------------------

var vnetName = 'vnet-${onpremName}'
var addressPrefix = '${baseNetworkAddress}.0.0/16'
var subnets = [
  {
    name: 'snet-default'
    addressPrefix: '${baseNetworkAddress}.0.0/24'
  }
  {
    name: 'GatewaySubnet'
    addressPrefix: '${baseNetworkAddress}.255.0/24'
  }
]
var unprotectedSubnets = [
  'GatewaySubnet'
]

// ----------------------------------------------------------------------------
// Resources
// ----------------------------------------------------------------------------

resource vnet 'Microsoft.Network/virtualNetworks@2019-11-01' = {
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

resource subnetnsg 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: 'nsg-${onpremName}'
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

module vm_default_01 '../../modules/compute-vm/compute-vm.bicep' = {
  dependsOn: [
    vnet
  ]
  name: 'deploy-vm-${onpremName}-01'
  params: {
    location: location
    vmName: '${onpremName}-01'
    vnetName: vnetName
    subnetName: 'snet-default'
    deployPublicIp: true
    osType: 'Linux'
    adminUsername: adminUsername
    adminPasswordOrKey: adminPassword
    authenticationType: 'password'
  }
}

module vpngw '../../modules/vpn-gateway/vpn-gateway.bicep' = if (deployVpnGw) {
  dependsOn: [
    vnet
  ]
  name: 'deploy-vpngw'
  params: {
    location: location
    vnetName: vnetName
    vgwNameSuffix: '${onpremName}-vpngw'
    enableBgp: true
    asn: 64512
  }
}

// ----------------------------------------------------------------------------
// Outputs
// ----------------------------------------------------------------------------

output vm_default_01 string = vm_default_01.outputs.hostname
