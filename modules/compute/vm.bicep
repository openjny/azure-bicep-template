// vm.bicep - Virtual Machine

@description('Azure region to deploy')
param location string = resourceGroup().location

@description('VM name suffix (e.g. "vm-<suffix>")')
@minLength(3)
@maxLength(15)
param nameSuffix string

@description('Host name')
@minLength(1)
@maxLength(15)
param computerName string = nameSuffix

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
param adminPasswordOrKey string

@description('Authentication type')
@allowed([
  'password'
  'ssh'
])
param authenticationType string = 'password'

@description('VNet name')
param vnetName string

@description('Subnet name')
param subnetName string

@description('NIC private IP address (opt)')
param privateIPAddress string = ''

@description('Load Balancer backend address pool id (opt)')
param lbBackendPoolId string = ''

@description('Deploys instance-level public IP if true')
param deployPublicIp bool = false

@description('PIP SKU')
@allowed([
  'Basic'
  'Standard'
])
param publicIpSku string = 'Standard'

@description('VM size (see "az vm list-sizes -l <loc>" for details)')
param vmSize string = 'Standard_B2s'

@description('Disk size in GB')
param osDiskSize int = 128

@description('Availability set Id (opt)')
param availabilitySetId string = ''

@description('Availability zone (opt)')
param zone string = ''

@description('Enable boot diagnostics')
param enableBootDiag bool = false

@description('Boot diagnostics storage URI')
param bootDiagStorageUri string = ''

@description('CustomData')
param customData string = ''

// ----------------------------------------------------------------------------
// Variables
// ----------------------------------------------------------------------------

var vmName = 'vm-${nameSuffix}'
var nicName = '${vmName}-nic-01'
var osDiskName = '${vmName}-osdisk'
var pipName = '${vmName}-pip'

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

resource pip 'Microsoft.Network/publicIPAddresses@2022-09-01' = if (deployPublicIp) {
  name: pipName
  location: location
  sku: {
    name: publicIpSku
  }
  zones: empty(zone) ? null : [
    zone
  ]
  properties: {
    publicIPAllocationMethod: (publicIpSku == 'Basic' ? 'Dynamic' : 'Static')
    publicIPAddressVersion: 'IPv4'
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2022-09-01' = {
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
          privateIPAllocationMethod: empty(privateIPAddress) ? 'Dynamic' : 'Static'
          privateIPAddress: empty(privateIPAddress) ? null : privateIPAddress
          publicIPAddress: !(deployPublicIp) ? null : {
            id: pip.id
          }
          loadBalancerBackendAddressPools: empty(lbBackendPoolId) ? null : [
            {
              id: lbBackendPoolId
            }
          ]
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: vmName
  location: location
  zones: empty(zone) ? null : [
    zone
  ]
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
      computerName: computerName
      adminUsername: adminUsername
      adminPassword: adminPasswordOrKey
      customData: empty(customData) ? null : customData
      linuxConfiguration: (authenticationType == 'ssh' && osType == 'linux') ? linuxConfigurationForSSH : null
      secrets: []
      allowExtensionOperations: true
    }
    diagnosticsProfile: (!enableBootDiag || empty(bootDiagStorageUri)) ? null : {
      bootDiagnostics: {
        enabled: true
        storageUri: bootDiagStorageUri
      }
    }
  }
}

// ----------------------------------------------------------------------------
// Outputs
// ----------------------------------------------------------------------------

output adminUsername string = adminUsername

output sshCommand string = 'ssh ${adminUsername}@${pip.properties.ipAddress}'
