@description('Azure region to deploy')
param location string = resourceGroup().location

@description('VM Name')
@minLength(3)
@maxLength(15)
param vmName string

@description('OS Type')
@allowed([
  'Linux'
  'Windows'
])
param osType string = 'Linux'

@description('Username')
param adminUsername string

@description('password or sshkey')
@minLength(12)
@secure()
param adminPasswordOrKey string = ''

@description('Authentication type')
@allowed([
  'password'
  'ssh'
])
param authenticationType string = 'password'

@description('VNet Name')
param vnetName string 

@description('Subnet Name')
param subnetName string

@description('Specify the private IP address of NIC if needed')
param privateIPAddress string = ''

@description('If true, NIC will have an instance-level Public IP (ILPIP)')
param deployPublicIp bool = true

@description('Domain name label for ILPIP')
param dnsLabelPrefix string = toLower('${vmName}-${uniqueString(resourceGroup().id, vmName)}')

@description('SKU for ILPIP')
@allowed([
  'Basic'
  'Standard'
])
param publicIpSku string = 'Basic'

@description('VM size (az vm list-sizes --location <loc>)')
param vmSize string = 'Standard_B2s'

@description('Disk size in GB')
param osDiskSize int = 32

@description('VM Availability Set ID')
param availabilitySetId string = ''

@description('CustomData')
param customData string = ''

// ----------------------------------------------------------------------------
// Variables
// ----------------------------------------------------------------------------

var nicName = 'nic-${vmName}'

var osDiskName = 'osdisk-${vmName}'

var publicIpName = 'pip-${vmName}'

var subnetId = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)

// # az vm image list --all -l japaneast -p Canonical --offer 0001-com-ubuntu-server-focal -o table
// # az vm image list --all -l japaneast -p Canonical --offer 0001-com-ubuntu-server-jammy -o table
// # az vm image list --all -l japaneast -p MicrosoftWindowsServer --offer WindowsServer -o table
var imageReferences = {
  Linux: {
    publisher: 'Canonical'
    offer: '0001-com-ubuntu-server-jammy'
    sku: '22_04-lts-gen2'
    version: 'latest'
  }
  Windows: {
    publisher: 'MicrosoftWindowsServer'
    offer: 'WindowsServer'
    sku: '2019-Datacenter'
    version: 'latest'
  }
}

var linuxConfigurationForSSH = {
  provisionVMAgent: true
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: adminPasswordOrKey
      }
    ]
  }
}

// ----------------------------------------------------------------------------
// Resources
// ----------------------------------------------------------------------------

resource pip 'Microsoft.Network/publicIPAddresses@2020-05-01' = if (deployPublicIp) {
  name: publicIpName
  location: location
  sku: {
    name: publicIpSku
  }
  properties: {
    publicIPAllocationMethod: (publicIpSku == 'Basic' ? 'Dynamic' : 'Static')
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: dnsLabelPrefix
    }
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2020-05-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: (empty(privateIPAddress) ? 'Dynamic' : 'Static')
          privateIPAddress: (empty(privateIPAddress) ? null : privateIPAddress)
          publicIPAddress: !(deployPublicIp) ? null : {
            id: pip.id
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2020-06-01' = {
  name: 'vm-${vmName}'
  location: location
  properties: {
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    availabilitySet: empty(availabilitySetId) ? null : {
      id: availabilitySetId
    }
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        name: osDiskName
        osType: osType
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        diskSizeGB: osDiskSize
      }
      dataDisks: []
      imageReference: imageReferences[osType]
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPasswordOrKey
      customData: (empty(customData) ? null : customData)
      linuxConfiguration: (authenticationType == 'ssh' && osType == 'linux') ? linuxConfigurationForSSH : json('null') 
      secrets: []
      allowExtensionOperations: true
    }
  }
}

// ----------------------------------------------------------------------------
// Outputs
// ----------------------------------------------------------------------------

output hostname string = pip.properties.dnsSettings.fqdn
