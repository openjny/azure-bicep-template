
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

@description('Number of public IP addresses')
param numPublicIpAddresses int = 1

// ----------------------------------------------------------------------------
// Variables
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// Resources
// ----------------------------------------------------------------------------

resource pip 'Microsoft.Network/publicIPAddresses@2021-08-01' = [for i in range(1, numPublicIpAddresses): {
  name: 'pip-${afwNameSuffix}-${padLeft(i, 2, '0')}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}]

resource afw 'Microsoft.Network/azureFirewalls@2021-08-01' = {
  name: 'afw-${afwNameSuffix}'
  location: location
  properties: {
    ipConfigurations: [for i in range(1, numPublicIpAddresses): {
      name: 'ipconfig${i}'
      properties: {
        subnet: (i > 1) ? null : {
          id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'AzureFirewallSubnet')
        }
        publicIPAddress: {
          id: pip[i].id
        }
      }
    }]
  }
}


// ----------------------------------------------------------------------------
// Outputs
// ----------------------------------------------------------------------------

