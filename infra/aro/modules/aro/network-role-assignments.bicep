@description('Name of the ARO spoke virtual network')
param spokeVnetName string

@description('Name of the control-plane subnet')
param masterSubnetName string = 'master-subnet'

@description('Name of the worker subnet')
param workerSubnetName string = 'worker-subnet'

@description('Name of the route table attached to ARO subnets')
param routeTableName string = 'aro-route-table'

@description('Principal IDs of the ARO platform workload identities')
param operatorIdentityPrincipalIds object

@description('Object ID of the Azure Red Hat OpenShift resource-provider service principal')
param aroResourceProviderObjectId string

resource spokeVirtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: spokeVnetName
}

resource masterSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: spokeVirtualNetwork
  name: masterSubnetName
}

resource workerSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: spokeVirtualNetwork
  name: workerSubnetName
}

resource routeTable 'Microsoft.Network/routeTables@2024-05-01' existing = {
  name: routeTableName
}

var subnetIdentityRoles = [
  {
    name: 'cloud-controller-manager'
    principalId: operatorIdentityPrincipalIds.cloudControllerManager
    roleDefinitionId: 'a1f96423-95ce-4224-ab27-4e3dc72facd4'
  }
  {
    name: 'ingress'
    principalId: operatorIdentityPrincipalIds.ingress
    roleDefinitionId: '0336e1d3-7a87-462b-b6db-342b63f7802c'
  }
  {
    name: 'machine-api'
    principalId: operatorIdentityPrincipalIds.machineApi
    roleDefinitionId: '0358943c-7e01-48ba-8889-02cc51d78637'
  }
  {
    name: 'aro-operator'
    principalId: operatorIdentityPrincipalIds.aroOperator
    roleDefinitionId: '4436bae4-7702-4c84-919b-c4069ff25ee2'
  }
]

var vnetIdentityRoles = [
  {
    name: 'cloud-network-config'
    principalId: operatorIdentityPrincipalIds.cloudNetworkConfig
    roleDefinitionId: 'be7a6435-15ae-4171-8f30-4a343eff9e8f'
  }
  {
    name: 'file-csi-driver'
    principalId: operatorIdentityPrincipalIds.fileCsiDriver
    roleDefinitionId: '0d7aedc0-15fd-4a67-a412-efad370c947e'
  }
  {
    name: 'image-registry'
    principalId: operatorIdentityPrincipalIds.imageRegistry
    roleDefinitionId: '8b32b316-c2f5-4ddf-b05b-83dacd2d08b5'
  }
]

var networkResourceIdentityRoles = concat(subnetIdentityRoles, vnetIdentityRoles)

resource masterSubnetIdentityRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for identityRole in subnetIdentityRoles: {
  name: guid(masterSubnet.id, identityRole.principalId, identityRole.roleDefinitionId)
  scope: masterSubnet
  properties: {
    principalId: identityRole.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', identityRole.roleDefinitionId)
  }
}]

resource workerSubnetIdentityRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for identityRole in subnetIdentityRoles: {
  name: guid(workerSubnet.id, identityRole.principalId, identityRole.roleDefinitionId)
  scope: workerSubnet
  properties: {
    principalId: identityRole.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', identityRole.roleDefinitionId)
  }
}]

resource vnetIdentityRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for identityRole in vnetIdentityRoles: {
  name: guid(spokeVirtualNetwork.id, identityRole.principalId, identityRole.roleDefinitionId)
  scope: spokeVirtualNetwork
  properties: {
    principalId: identityRole.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', identityRole.roleDefinitionId)
  }
}]

resource routeTableIdentityRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for identityRole in networkResourceIdentityRoles: {
  name: guid(routeTable.id, identityRole.principalId, identityRole.roleDefinitionId)
  scope: routeTable
  properties: {
    principalId: identityRole.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', identityRole.roleDefinitionId)
  }
}]

resource aroResourceProviderVnetRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(spokeVirtualNetwork.id, aroResourceProviderObjectId, 'aro-network-role')
  scope: spokeVirtualNetwork
  properties: {
    principalId: aroResourceProviderObjectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '42f3c60f-e7b1-46d7-ba56-6de681664342')
  }
}

resource aroResourceProviderRouteTableRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(routeTable.id, aroResourceProviderObjectId, 'aro-network-role')
  scope: routeTable
  properties: {
    principalId: aroResourceProviderObjectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '42f3c60f-e7b1-46d7-ba56-6de681664342')
  }
}
