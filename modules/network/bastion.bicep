// bastion.bicep - Bastion Host

@description('Region to deploy')
param location string = resourceGroup().location

@description('VNet name')
param vnetName string

@description('Bastion host name suffix (e.g. "bas-<suffix>")')
param nameSuffix string

@description('Bastion host SKU')
@allowed([
  'Basic'
  'Standard'
])
param skuName string = 'Standard'

@description('The scale units (between 2 - 50)')
param scaleUnits int = 2

@description('Enable Kerberos authentication')
param enableKerberos bool = false

@description('Disable copy and paste (only for Standard SKU)')
param disableCopyPaste bool = false

@description('Enable file copy (only for Standard SKU)')
param enableFileCopy bool = true

@description('Enable IP-based connection (only for Standard SKU)')
param enableIpConnect bool = true

@description('Enable shareable link (only for Standard SKU)')
param enableShareableLink bool = true

@description('Enable native client support (only for Standard SKU)')
param enableTunneling bool = true

// ----------------------------------------------------------------------------
// Variables
// ----------------------------------------------------------------------------

var bastionName = 'bas-${nameSuffix}'

var pipName = '${bastionName}-pip'

var bastionSubnetId = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'AzureBastionSubnet')

var isBasic = skuName == 'Basic'

// ----------------------------------------------------------------------------
// Resources
// ----------------------------------------------------------------------------

resource pip 'Microsoft.Network/publicIPAddresses@2022-09-01' = {
  name: pipName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2022-09-01' = {
  name: bastionName
  location: location
  sku: {
    name: skuName
  }
  properties: {
    enableKerberos: enableKerberos
    disableCopyPaste: isBasic ? false : disableCopyPaste
    enableFileCopy: isBasic ? false : enableFileCopy
    enableIpConnect: isBasic ? false : enableIpConnect
    enableShareableLink: isBasic ? false : enableShareableLink
    enableTunneling: isBasic ? false : enableTunneling
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: bastionSubnetId
          }
          publicIPAddress: {
            id: pip.id
          }
        }
      }
    ]
    scaleUnits: scaleUnits
  }
}

// ----------------------------------------------------------------------------
// Outputs
// ----------------------------------------------------------------------------

output pip object = pip

output bastion object = bastion
