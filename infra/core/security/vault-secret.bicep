param keyVaultName string
param keyVaultSecretName string
@secure()
param keyVaultSecretValue string

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource keyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: keyVaultSecretName
  properties: {
    value: keyVaultSecretValue
  }
}

output secretName string = keyVaultSecretName
output secretUri string = keyVaultSecret.properties.secretUri
