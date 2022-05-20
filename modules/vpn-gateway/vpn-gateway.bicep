@description('Region to deploy')
param location string = resourceGroup().location

@description('VNet Name')
param vnetName string

@description('VPN Gateway Name (without prefix "vgw-")')
param gwNameSuffix string

@description('Gateway SKU Name')
@allowed([
  'Basic'
  'VpnGw1'
  'VpnGw1AZ'
  'VpnGw2'
  'VpnGw2AZ'
  'VpnGw3'
  'VpnGw3AZ'
  'VpnGw4'
  'VpnGw4AZ'
  'VpnGw5'
  'VpnGw5AZ'
])
param skuName string = 'VpnGw1'

@description('The generation for this VirtualNetworkGateway')
@allowed([
  'Generation1'
  'Generation2'
])
param vpnGatewayGeneration string = 'Generation1'

@description('Whether BGP is enabled for this virtual network gateway or not')
param enableBgp bool = true

@description('The BGP speaker\'s ASN (private: 64512-65514 and 65521-65534)')
param asn int = 65515

@description('Whether Active/Active or Active/Standby')
param activeActive bool = false

// ----------------------------------------------------------------------------
// Variables
// ----------------------------------------------------------------------------

var zoneRedundantSkus = [
  'VpnGw1AZ'
  'VpnGw2AZ'
  'VpnGw3AZ'
  'VpnGw4AZ'
  'VpnGw5AZ'  
]

var isZoneRedundant = contains(zoneRedundantSkus, skuName)

// ----------------------------------------------------------------------------
// Resources
// ----------------------------------------------------------------------------

resource pip 'Microsoft.Network/publicIPAddresses@2021-08-01' = {
  name: 'pip-${gwNameSuffix}'
  location: location
  sku: {
    name: isZoneRedundant ? 'Standard' : 'Basic'
  }
  properties: {
    publicIPAllocationMethod: isZoneRedundant ? 'Static' : 'Dynamic'
    publicIPAddressVersion: 'IPv4'
  }
  zones: !isZoneRedundant ? null : [
    '1'
    '2'
    '3'
  ]
}

resource vgw 'Microsoft.Network/virtualNetworkGateways@2020-06-01' = {
  name: 'vgw-${gwNameSuffix}'
  location: location
  properties: {
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    activeActive: activeActive
    vpnGatewayGeneration: vpnGatewayGeneration
    sku: {
      name: skuName
      tier: skuName
    }
    enableBgp: enableBgp
    bgpSettings: {
      asn: asn
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'GatewaySubnet')
          }
          publicIPAddress: {
            id: pip.id
          }
        }
      }
    ]
  }
}

// ----------------------------------------------------------------------------
// Outputs
// ----------------------------------------------------------------------------

output pip object = pip
output vgw object = vgw
