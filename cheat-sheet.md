## Bicep: Cheat Sheet

## Parameter

```bicep
param uniqueName string = '${uniqueString(resourceGroup().id)}'

@secure()
param password string

# Description
@description('Must be at least Standard_A3 to support 2 NICs.')
param shortDescription string

@description('''
Storage account name restrictions:
- Storage account names must be between 3 and 24 characters in length and may contain numbers and lowercase letters only.
- Your storage account name must be unique within Azure. No two storage accounts can have the same name.
''')
param longDescription string

@allowed([
  'one'
  'two'
])
param enumVariable string

@minLength(3)
@maxLength(24)
param storageAccountName string

@minValue(1)
@maxValue(12)
param month int
```

```bicep
param vNetSettings object = {
  name: 'VNet1'
  location: 'eastus'
  addressPrefixes: [
    {
      name: 'firstPrefix'
      addressPrefix: '10.0.0.0/22'
    }
  ]
  subnets: [
    {
      name: 'firstSubnet'
      addressPrefix: '10.0.0.0/24'
    }
    {
      name: 'secondSubnet'
      addressPrefix: '10.0.1.0/24'
    }
  ]
}
```

Configuration Pattern

```bicep
@allowed([
  'test'
  'prod'
])
param environmentName string

var environmentSettings = {
  test: {
    instanceSize: 'Small'
    instanceCount: 1
  }
  prod: {
    instanceSize: 'Large'
    instanceCount: 4
  }
}

output instanceSize string = environmentSettings[environmentName].instanceSize
output instanceCount int = environmentSettings[environmentName].instanceCount
```

## Condition

```bicep
param deployStorage bool = true
param storageName string
param location string = resourceGroup().location

resource myStorageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = if (deployStorage) {
  name: storageName
  location: location
  ...
}

output endpoint string = deployStorage ? myStorageAccount.properties.primaryEndpoints.blob : ''
```