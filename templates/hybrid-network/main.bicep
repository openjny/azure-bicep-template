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

var onprem = {
  location: location
  envName: 'onprem'
  addressSpace: '192.168.0.0/16'
  subnets: [
    {
      name: 'default'
      addressPrefix: '192.168.0.0/24'
    }
    {
      name: 'GatewaySubnet'
      addressPrefix: '192.168.255.0/24'
    }
  ]
}

var hub = {
  addressSpace: '10.0.0.0/16'
  subnets: [
    {
      name: 'default'
      addressPrefix: '10.0.0.0/24'
    }
    {
      name: 'AzureBastionSubnet'
      addressPrefix: '10.0.1.0/24'
    }
    {
      name: 'GatewaySubnet'
      addressPrefix: '10.0.2.0/24'
    }
    {
      name: 'RouteServerSubnet'
      addressPrefix: '10.0.3.0/24'
    }
    {
      name: 'AzureFirewallSubnet'
      addressPrefix: '10.0.4.0/24'
    }
    {
      name: 'AzureFirewallManagementSubnet'
      addressPrefix: '10.0.5.0/24'
    }
  ]
}

var spokes = [
  {
    name: 'spoke-01'
    addressSpace: '10.1.0.0/16'
    subnets: [
      {
        name: 'default'
        addressPrefix: '10.1.0.0/24'
      }
    ]
  }
  {
    name: 'spoke-02'
    addressSpace: '10.2.0.0/16'
    subnets: [
      {
        name: 'default'
        addressPrefix: '10.2.0.0/24'
      }
    ]
  }
]

// ----------------------------------------------------------------------------
// Resources - onprem
// ----------------------------------------------------------------------------

resource onprem_nsg 'Microsoft.Network/networkSecurityGroups@2022-09-01' = {
  name: 'nsg-${onprem.envName}'
  location: onprem.location
  properties: {
    securityRules: empty(sourceAddressPrefix) ? null : securityRules
  }
}

resource onprem_vnet 'Microsoft.Network/virtualNetworks@2022-09-01' = {
  location: onprem.location
  name: 'vnet-${onprem.envName}'
  properties: {
    addressSpace: {
      addressPrefixes: [
        onprem.addressSpace
      ]
    }
    subnets: [for (subnet, i) in onprem.subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
        networkSecurityGroup: contains(unprotectedSubnets, subnet.name) ? null : {
          id: onprem_nsg.id
        }
      }
    }]
  }
}

module onprem_vpngw '../../modules/network/vpngw.bicep' = {
  name: 'deploy-onprem-vpngw'
  params: {
    location: onprem.location
    nameSuffix: onprem.envName
    vnetName: onprem_vnet.name
    enableBgp: true
    asn: 64512
    skuName: 'VpnGw1'
  }
}

module onprem_vm '../../modules/compute/vm.bicep' = {
  name: 'deploy-vm-${onprem.envName}'
  params: {
    location: location
    nameSuffix: onprem.envName
    vnetName: onprem_vnet.name
    subnetName: 'default'
    deployPublicIp: true
    osType: 'Linux'
    adminUsername: adminUsername
    adminPasswordOrKey: adminPassword
    authenticationType: 'password'
  }
}

// ----------------------------------------------------------------------------
// Resources - Azure Hub Spoke
// ----------------------------------------------------------------------------

resource nsg 'Microsoft.Network/networkSecurityGroups@2022-09-01' = {
  name: 'nsg-hub-spoke'
  location: location
  properties: {
    securityRules: empty(sourceAddressPrefix) ? null : securityRules
  }
}

resource hub_vnet 'Microsoft.Network/virtualNetworks@2022-09-01' = {
  location: location
  name: 'vnet-hub'
  properties: {
    addressSpace: {
      addressPrefixes: [
        hub.addressSpace
      ]
    }
    subnets: [for (subnet, i) in hub.subnets: {
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

module hub_vpngw '../../modules/network/vpngw.bicep' = {
  name: 'deploy-hub-vpngw'
  params: {
    location: location
    nameSuffix: 'hub'
    vnetName: hub_vnet.name
    enableBgp: true
    asn: 65515
    skuName: 'VpnGw1'
  }
}

resource spoke_vnets 'Microsoft.Network/virtualNetworks@2022-09-01' = [for (spoke, i) in spokes: {
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

resource peering_hub_to_spoke 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-09-01' = [for (spoke, i) in spokes: {
  dependsOn: [
    hub_vpngw
  ]
  parent: hub_vnet
  name: 'peering-hub-to-${spoke.name}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: spoke_vnets[i].id
    }
  }
}]

resource peering_spoke_to_hub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-09-01' = [for (spoke, i) in spokes: {
  dependsOn: [
    hub_vpngw
  ]
  parent: spoke_vnets[i]
  name: 'peering-${spoke.name}-to-hub'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: true
    remoteVirtualNetwork: {
      id: hub_vnet.id
    }
  }
}]

module spoke_vms '../../modules/compute/vm.bicep' = [for (spoke, i) in spokes: {
  dependsOn: [
    spoke_vnets
  ]
  name: 'deploy-vm-${spoke.name}'
  params: {
    location: location
    nameSuffix: '${spoke.name}'
    vnetName: spoke_vnets[i].name
    subnetName: 'default'
    deployPublicIp: true
    osType: 'Linux'
    adminUsername: adminUsername
    adminPasswordOrKey: adminPassword
    authenticationType: 'password'
  }
}]
