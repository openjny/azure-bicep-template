# azure-bicep-template

https://docs.microsoft.com/ja-jp/azure/azure-resource-manager/bicep/

## Usage

```bash
LOC="japaneast"
RG="rg-test"

az group create --name $RG --location $LOC
az deployment group create -g $RG --template-file main.bicep
```

## Advanced usage

Azure CLI on bash

```bash
ADMIN_USERNAME="azureuser"
ADMIN_PASSWORD="strongpasswordhere"
SOURCE_ADDRESS_PREFIX="$(curl ifconfig.me)"

params = "adminUsername=$ADMIN_USERNAME adminPassword=$ADMIN_PASSWORD sourceAddressPrefix=$SOURCE_ADDRESS_PREFIX"
az deployment group create -g $RG --template-file main.bicep --parameters $params
```

Azure CLI on PowerShell

```powershell
$ADMIN_USERNAME="azureuser"
$ADMIN_PASSWORD="strongpasswordhere"
$SOURCE_ADDRESS_PREFIX=$(curl.exe -4 ifconfig.co)

$params = @{
    adminUsername = @{value = $ADMIN_USERNAME}
    adminPassword = @{value = $ADMIN_PASSWORD}
    sourceAddressPrefix = @{value = $SOURCE_ADDRESS_PREFIX}
}
$params = $params | ConvertTo-Json -Compress
$params = $params.Replace('"', '\"')
az deployment group create -g $RG --template-file main.bicep --parameters $params
```