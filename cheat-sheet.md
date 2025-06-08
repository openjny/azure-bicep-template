# Bicep: Cheat Sheet

## 命名規則

命名規則の目的
- リソース名は一意である必要がある。
- 環境ごとに区別できるようにする。
- 意味のある名前にして、リソースの用途や環境がわかるようにする。
- Azureリソースごとに名前の長さや使用可能な文字に制限があるため、それに準拠する。

命名規則のベストプラクティス
- 小文字のキャメルケース（lower camel case）を使う例が多い。
- uniqueString()関数を使って、リソースグループIDなどを元に一意の文字列を生成し、名前の一部に含める。
- 名前はテンプレート式で組み立てる（例: ${shortAppName}-${environment}-${uniqueString(resourceGroup().id)}）。
- 名前の先頭に数字が来ないようにプレフィックスを付ける（特にストレージアカウントなど）。
- 変数やパラメータ名にnameを使わず、リソースを表す名前にする（例: cosmosDBAccountなど）。
- パラメータの文字数制限を設けて、名前の長さ制限に対応する。

命名規則の構成例
- リソースタイプの略称（例: vnetはVirtual Network）
- ワークロードやアプリケーション名
- 環境名の略称（例: dev, prd）
- Azureリージョンの略称（例: nweはNorway East）
- インスタンス識別子（例: 001やmain）

## パターン

グローバルに固有な値を取得する

```bicep
param uniqueName string = '${uniqueString(resourceGroup().id)}'
```

パラメータと hashed-map を組み合わせる

```bicep
@allowed([
  'test'
  'prod'
])
param envName string

var envSettings = {
  test: {
    instanceSize: 'Small'
    instanceCount: 1
  }
  prod: {
    instanceSize: 'Large'
    instanceCount: 4
  }
}

// envSettings[envName].instanceSize などを使用する
```

条件

```bicep
param deployStorage bool = true

resource myStorageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = if (deployStorage) {
  name: storageName
  // and more
}

output endpoint string = deployStorage ? myStorageAccount.properties.primaryEndpoints.blob : ''
```