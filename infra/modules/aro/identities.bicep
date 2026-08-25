@description('Azure region for the ARO managed identities')
param location string = resourceGroup().location

resource clusterIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'aro-cluster'
  location: location
}

resource cloudControllerManagerIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'cloud-controller-manager'
  location: location
}

resource ingressIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'ingress'
  location: location
}

resource machineApiIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'machine-api'
  location: location
}

resource diskCsiDriverIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'disk-csi-driver'
  location: location
}

resource cloudNetworkConfigIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'cloud-network-config'
  location: location
}

resource imageRegistryIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'image-registry'
  location: location
}

resource fileCsiDriverIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'file-csi-driver'
  location: location
}

resource aroOperatorIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'aro-operator'
  location: location
}

resource cloudControllerManagerFederatedCredentialRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(cloudControllerManagerIdentity.id, clusterIdentity.id, 'federated-credential')
  scope: cloudControllerManagerIdentity
  properties: {
    principalId: clusterIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ef318e2a-8334-4a05-9e4a-295a196c6a6e')
  }
}

resource ingressFederatedCredentialRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(ingressIdentity.id, clusterIdentity.id, 'federated-credential')
  scope: ingressIdentity
  properties: {
    principalId: clusterIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ef318e2a-8334-4a05-9e4a-295a196c6a6e')
  }
}

resource machineApiFederatedCredentialRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(machineApiIdentity.id, clusterIdentity.id, 'federated-credential')
  scope: machineApiIdentity
  properties: {
    principalId: clusterIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ef318e2a-8334-4a05-9e4a-295a196c6a6e')
  }
}

resource diskCsiDriverFederatedCredentialRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(diskCsiDriverIdentity.id, clusterIdentity.id, 'federated-credential')
  scope: diskCsiDriverIdentity
  properties: {
    principalId: clusterIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ef318e2a-8334-4a05-9e4a-295a196c6a6e')
  }
}

resource cloudNetworkConfigFederatedCredentialRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(cloudNetworkConfigIdentity.id, clusterIdentity.id, 'federated-credential')
  scope: cloudNetworkConfigIdentity
  properties: {
    principalId: clusterIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ef318e2a-8334-4a05-9e4a-295a196c6a6e')
  }
}

resource imageRegistryFederatedCredentialRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(imageRegistryIdentity.id, clusterIdentity.id, 'federated-credential')
  scope: imageRegistryIdentity
  properties: {
    principalId: clusterIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ef318e2a-8334-4a05-9e4a-295a196c6a6e')
  }
}

resource fileCsiDriverFederatedCredentialRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(fileCsiDriverIdentity.id, clusterIdentity.id, 'federated-credential')
  scope: fileCsiDriverIdentity
  properties: {
    principalId: clusterIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ef318e2a-8334-4a05-9e4a-295a196c6a6e')
  }
}

resource aroOperatorFederatedCredentialRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aroOperatorIdentity.id, clusterIdentity.id, 'federated-credential')
  scope: aroOperatorIdentity
  properties: {
    principalId: clusterIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ef318e2a-8334-4a05-9e4a-295a196c6a6e')
  }
}

output clusterIdentityResourceId string = clusterIdentity.id

output operatorIdentityResourceIds object = {
  cloudControllerManager: cloudControllerManagerIdentity.id
  ingress: ingressIdentity.id
  machineApi: machineApiIdentity.id
  diskCsiDriver: diskCsiDriverIdentity.id
  cloudNetworkConfig: cloudNetworkConfigIdentity.id
  imageRegistry: imageRegistryIdentity.id
  fileCsiDriver: fileCsiDriverIdentity.id
  aroOperator: aroOperatorIdentity.id
}

output operatorIdentityPrincipalIds object = {
  cloudControllerManager: cloudControllerManagerIdentity.properties.principalId
  ingress: ingressIdentity.properties.principalId
  machineApi: machineApiIdentity.properties.principalId
  diskCsiDriver: diskCsiDriverIdentity.properties.principalId
  cloudNetworkConfig: cloudNetworkConfigIdentity.properties.principalId
  imageRegistry: imageRegistryIdentity.properties.principalId
  fileCsiDriver: fileCsiDriverIdentity.properties.principalId
  aroOperator: aroOperatorIdentity.properties.principalId
}
