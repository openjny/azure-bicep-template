# azure-bicep-template

https://docs.microsoft.com/ja-jp/azure/azure-resource-manager/bicep/

## Usage

```bash
LOC="japaneast"
RG="rg-test"

az group create --name $RG --location $LOC
az deployment group create -g $RG --template-file main.bicep
az deployment group create -g $rg --template-file main.bicep --parameters sourceAddressPrefix=$(curl -4s ifconfig.me)
```

## パスワード・SSHキーの推奨要件

- パスワードの場合は12文字以上で、英大文字・小文字・数字・記号を含めることを推奨します。
- SSHキーの場合は有効な公開鍵形式（例: ssh-rsa, ssh-ed25519 など）を指定してください。

### Bashでのパスワードバリデーション例
```bash
ADMIN_PASSWORD="yourpasswordhere"
if [[ ! $ADMIN_PASSWORD =~ [A-Z] ]] || \
   [[ ! $ADMIN_PASSWORD =~ [a-z] ]] || \
   [[ ! $ADMIN_PASSWORD =~ [0-9] ]] || \
   [[ ! $ADMIN_PASSWORD =~ [^A-Za-z0-9] ]] || \
   [[ ${#ADMIN_PASSWORD} -lt 12 ]]; then
  echo "パスワードは12文字以上で英大文字・小文字・数字・記号を含めてください。"
  exit 1
fi
```

### PowerShellでのパスワードバリデーション例
```powershell
$ADMIN_PASSWORD = "yourpasswordhere"
if ($ADMIN_PASSWORD.Length -lt 12 -or
    $ADMIN_PASSWORD -notmatch '[A-Z]' -or
    $ADMIN_PASSWORD -notmatch '[a-z]' -or
    $ADMIN_PASSWORD -notmatch '[0-9]' -or
    $ADMIN_PASSWORD -notmatch '[^A-Za-z0-9]') {
    Write-Host "パスワードは12文字以上で英大文字・小文字・数字・記号を含めてください。"
    exit 1
}
```

## Advanced usage

Azure CLI on bash

```bash
ADMIN_USERNAME="azureuser"
ADMIN_PASSWORD="Str0ngP@ssw0rd!"
SOURCE_ADDRESS_PREFIX="$(curl -4s ifconfig.me)"

params = "adminUsername=$ADMIN_USERNAME adminPassword=$ADMIN_PASSWORD sourceAddressPrefix=$SOURCE_ADDRESS_PREFIX"
az deployment group create -g $RG --template-file main.bicep --parameters $params
```

Azure CLI on PowerShell

```powershell
$ADMIN_USERNAME="azureuser"
$ADMIN_PASSWORD="Str0ngP@ssw0rd!"
$SOURCE_ADDRESS_PREFIX=$(curl.exe -4s ifconfig.co)

$params = @{
    adminUsername = @{value = $ADMIN_USERNAME}
    adminPassword = @{value = $ADMIN_PASSWORD}
    sourceAddressPrefix = @{value = $SOURCE_ADDRESS_PREFIX}
}
$params = $params | ConvertTo-Json -Compress
$params = $params.Replace('"', '\"')
az deployment group create -g $RG --template-file main.bicep --parameters $params
```
