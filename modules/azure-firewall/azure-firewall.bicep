// azure-firewall.bicep

@description('Region to deploy')
param location string = resourceGroup().location

@description('Azure Firewall name (without prefix "afw-")')
param afwNameSuffix string

@description('VNet Name')
param vnetName string

@description('Tier of an Azure Firewall')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param tier string = 'Standard'

@description('The operation mode for Threat Intel.')
@allowed([
  'Alert'
  'Deny'
  'Off'
])
param threatIntelMode string = 'Alert'

@description('Number of public IP addresses')
param numPublicIpAddresses int = 1

@description('If true, all traffic from private network will be allowed')
param allowFromRFC1918 bool = true

// @description('If true, diagnostic logs will be enabled')
// param enableDiagnostics bool = false

@description('The full ARM resource ID of the Log Analytics workspace to which you would like to send Diagnostic Logs.')
param diagWorkspaceId string = ''

@description('The resource ID of the storage account to which you would like to send Diagnostic Logs.')
param diagStorageAccountId string = ''

// ----------------------------------------------------------------------------
// Variables
// ----------------------------------------------------------------------------

var enableDiagnostics = !(empty(diagWorkspaceId) && empty(diagStorageAccountId))

var retentionPolicy = {
  days: 0
  enabled: false
}

// ----------------------------------------------------------------------------
// Resources
// ----------------------------------------------------------------------------

resource pip 'Microsoft.Network/publicIPAddresses@2021-08-01' = [for i in range(0, numPublicIpAddresses): {
  name: 'pip-afw-${afwNameSuffix}-${padLeft(i+1, 2, '0')}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}]

// ref: https://docs.microsoft.com/en-us/azure/templates/microsoft.network/azurefirewalls?tabs=bicep

resource afw 'Microsoft.Network/azureFirewalls@2021-08-01' = {
  name: 'afw-${afwNameSuffix}'
  location: location
  properties: {
    sku: {
      name:'AZFW_VNet'
      tier: tier
    }
    threatIntelMode: threatIntelMode
    ipConfigurations: [for i in range(0, numPublicIpAddresses): {
      name: 'ipconfig${i+1}'
      properties: {
        subnet: (i != 0) ? null : {
          id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'AzureFirewallSubnet')
        }
        publicIPAddress: {
          id: pip[i].id
        }
      }
    }]
    networkRuleCollections: !allowFromRFC1918 ? null : [
      {
        name: 'net-rule-collection-01'
        properties: {
          priority: 200
          action: {
            type: 'Allow'
          }
          rules: [
            {
              name: 'net-rule-rfc1918'
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
  }
}

resource diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics) {
  name: 'diag-afw-${afwNameSuffix}'
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
