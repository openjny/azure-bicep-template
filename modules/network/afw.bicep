// afw.bicep - Azure Firewall

@description('Region to deploy')
param location string = resourceGroup().location

@description('Azure Firewall name suffix (e.g. "afw-<suffix>")')
param nameSuffix string

@description('VNet Name')
param vnetName string

@description('Tier of Azure Firewall')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param tier string = 'Standard'

@description('The operation mode for Threat Intel')
@allowed([
  'Alert'
  'Deny'
  'Off'
])
param threatIntelMode string = 'Alert'

@description('Availability zone numbers')
param zones array = [
  '1'
  '2'
  '3'
]

@description('Number of public IP addresses')
param numPublicIpAddresses int = 1

@description('Enable firewall policy (Azure Firewall Manager)')
param enableFirewallPolicy bool = true

@description('If true, all traffic from private network will be allowed')
param allowFromRFC1918 bool = true

@description('The full ARM resource ID of the Log Analytics workspace to which you would like to send Diagnostic Logs')
param diagWorkspaceId string = ''

@description('The resource ID of the storage account to which you would like to send Diagnostic Logs')
param diagStorageAccountId string = ''

// ----------------------------------------------------------------------------
// Variables
// ----------------------------------------------------------------------------

var afwName = 'afw-${nameSuffix}'

var afwpName = 'afwp-${nameSuffix}'

var classicNetworkRuleCollections = [
  {
    name: 'default-allow-net-collection'
    properties: {
      priority: 300
      action: {
        type: 'Allow'
      }
      rules: [
        {
          name: 'allow-from-rfc1918'
          protocols: [
            'Any'
          ]
          sourceAddresses: [
            '10.0.0.0/8'
            '172.16.0.0/12'
            '192.168.0.0/16'
          ]
          destinationAddresses: [
            '*'
          ]
          destinationPorts: [
            '*'
          ]
        }
      ]
    }
  }
]

var enableDiagnostics = !(empty(diagWorkspaceId) && empty(diagStorageAccountId))

var retentionPolicy = {
  days: 0
  enabled: false
}

// ----------------------------------------------------------------------------
// Resources
// ----------------------------------------------------------------------------

resource pip 'Microsoft.Network/publicIPAddresses@2022-07-01' = [for i in range(0, numPublicIpAddresses): {
  name: '${afwName}-pip-${padLeft(i + 1, 2, '0')}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
  zones: zones
}]

resource afwp 'Microsoft.Network/firewallPolicies@2022-09-01' = if (enableFirewallPolicy) {
  name: afwpName
  location: location
  properties: {
    threatIntelMode: threatIntelMode
  }
}

resource afwpDefaultNetRules 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2022-09-01' = if (enableFirewallPolicy) {
  parent: afwp
  name: 'DefaultNetworkRuleCollectionGroup'
  properties: {
    priority: 300
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        name: 'default-net-allow-collections'
        priority: 300
        rules: !allowFromRFC1918 ? null : [
          {
            ruleType: 'NetworkRule'
            name: 'allow-from-rfc1918'
            ipProtocols: [
              'Any'
            ]
            sourceAddresses: [
              '10.0.0.0/8'
              '172.16.0.0/12'
              '192.168.0.0/16'
            ]
            destinationAddresses: [
              '*'
            ]
            destinationPorts: [
              '*'
            ]
          }
        ]
      }
    ]
  }
}

// ref: https://docs.microsoft.com/en-us/azure/templates/microsoft.network/azurefirewalls?tabs=bicep

resource afw 'Microsoft.Network/azureFirewalls@2022-07-01' = {
  dependsOn: [
    afwp
    afwpDefaultNetRules
  ]
  name: afwName
  location: location
  zones: zones
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: tier
    }
    threatIntelMode: threatIntelMode
    ipConfigurations: [for i in range(0, numPublicIpAddresses): {
      name: 'ipconfig${i + 1}'
      properties: {
        subnet: (i != 0) ? null : {
          id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'AzureFirewallSubnet')
        }
        publicIPAddress: {
          id: pip[i].id
        }
      }
    }]
    networkRuleCollections: (!enableDiagnostics && allowFromRFC1918) ? classicNetworkRuleCollections : null
    firewallPolicy: !enableFirewallPolicy ? null : {
      id: afwp.id
    }
  }
}

resource diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics) {
  name: 'diag-${afwName}'
  scope: afw
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
  }
}

// ----------------------------------------------------------------------------
// Outputs
// ----------------------------------------------------------------------------
