// VPN Gateway

@description('Region to deploy')
param location string = resourceGroup().location

@description('VPN Gateway name suffix (e.g. "vpngw-<suffix>")')
param nameSuffix string

@description('VNet Name')
param vnetName string

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

@description('The resourceid of the Log Analytics Workspace to which you would like to send logs')
param diagWorkspaceId string = ''

@description('The resourceid of the Storage Account to which you would like to send logs')
param diagStorageAccountId string = ''

// ----------------------------------------------------------------------------
// Variables
// ----------------------------------------------------------------------------

var vpngwName = 'vpngw-${nameSuffix}'

var zoneRedundantSkus = [
  'VpnGw1AZ'
  'VpnGw2AZ'
  'VpnGw3AZ'
  'VpnGw4AZ'
  'VpnGw5AZ'
]

var isZoneRedundant = contains(zoneRedundantSkus, skuName)

// calc the # of required pips
var numPublicIpAddresses = activeActive ? 2 : 1

// diagnostic settings
var enableDiagnostics = !(empty(diagWorkspaceId) && empty(diagStorageAccountId))

var retentionPolicy = {
  days: 0
  enabled: false
}

// ----------------------------------------------------------------------------
// Resources
// ----------------------------------------------------------------------------

resource pip 'Microsoft.Network/publicIPAddresses@2022-01-01' = [for i in range(0, numPublicIpAddresses): {
  name: '${vpngwName}-pip-${padLeft(i + 1, 2, '0')}'
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
}]

// ref:
// https://docs.microsoft.com/en-us/azure/templates/microsoft.network/virtualnetworkgateways?tabs=bicep

resource vgw 'Microsoft.Network/virtualNetworkGateways@2022-07-01' = {
  name: vpngwName
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
    ipConfigurations: [for i in range(0, numPublicIpAddresses): {
      name: 'ipconfig${i}'
      properties: {
        privateIPAllocationMethod: 'Dynamic'
        subnet: {
          id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'GatewaySubnet')
        }
        publicIPAddress: {
          id: pip[i].id
        }
      }
    }]
  }
}

resource diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics) {
  name: 'diag-${vpngwName}'
  scope: vgw
  properties: {
    workspaceId: empty(diagWorkspaceId) ? null : diagWorkspaceId
    storageAccountId: empty(diagStorageAccountId) ? null : diagStorageAccountId
    logs: [
      {
        category: null
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: retentionPolicy
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: retentionPolicy
      }
    ]
  }
}

// ----------------------------------------------------------------------------
// Outputs
// ----------------------------------------------------------------------------

output pip array = [for i in range(0, numPublicIpAddresses): {
  pip: pip[i]
}]

output vgw object = vgw
