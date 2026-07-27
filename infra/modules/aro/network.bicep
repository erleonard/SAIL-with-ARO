@description('Azure region for the ARO network')
param location string = resourceGroup().location

@description('Name of the virtual network')
param vnetName string

@description('Virtual network address space')
param vnetAddressPrefix string = '192.168.0.0/16'

@description('Name of the control-plane subnet')
param masterSubnetName string = 'master-subnet'

@description('Control-plane subnet address prefix')
param masterSubnetPrefix string = '192.168.2.0/24'

@description('Name of the worker subnet')
param workerSubnetName string = 'worker-subnet'

@description('Worker subnet address prefix')
param workerSubnetPrefix string = '192.168.4.0/23'

@description('Name of the private-endpoint subnet')
param privateEndpointSubnetName string = 'pe-subnet'

@description('Private-endpoint subnet address prefix')
param privateEndpointSubnetPrefix string = '192.168.0.0/24'

@description('Name of the route table attached to the ARO subnets')
param routeTableName string = 'aro-route-table'

@description('Private IP address of the Protected B firewall used for outbound traffic')
param firewallPrivateIpAddress string

@description('Principal IDs of the ARO platform workload identities')
param operatorIdentityPrincipalIds object

@description('Object ID of the Azure Red Hat OpenShift resource-provider service principal')
param aroResourceProviderObjectId string

@description('Tags applied to network resources')
param tags object = {}

resource routeTable 'Microsoft.Network/routeTables@2024-05-01' = {
  name: routeTableName
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: false
  }
}

resource defaultRoute 'Microsoft.Network/routeTables/routes@2024-05-01' = {
  parent: routeTable
  name: 'default-via-firewall'
  properties: {
    addressPrefix: '0.0.0.0/0'
    nextHopType: 'VirtualAppliance'
    nextHopIpAddress: firewallPrivateIpAddress
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: masterSubnetName
        properties: {
          addressPrefix: masterSubnetPrefix
          privateLinkServiceNetworkPolicies: 'Disabled'
          routeTable: {
            id: routeTable.id
          }
          serviceEndpoints: [
            {
              service: 'Microsoft.ContainerRegistry'
            }
          ]
        }
      }
      {
        name: workerSubnetName
        properties: {
          addressPrefix: workerSubnetPrefix
          routeTable: {
            id: routeTable.id
          }
          serviceEndpoints: [
            {
              service: 'Microsoft.ContainerRegistry'
            }
          ]
        }
      }
      {
        name: privateEndpointSubnetName
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

resource masterSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: virtualNetwork
  name: masterSubnetName
}

resource workerSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: virtualNetwork
  name: workerSubnetName
}

resource privateEndpointSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: virtualNetwork
  name: privateEndpointSubnetName
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
  name: guid(virtualNetwork.id, identityRole.principalId, identityRole.roleDefinitionId)
  scope: virtualNetwork
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
  name: guid(virtualNetwork.id, aroResourceProviderObjectId, 'aro-network-role')
  scope: virtualNetwork
  properties: {
    principalId: aroResourceProviderObjectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '42f3c60f-e7b1-46d7-ba56-6de681664342')
  }
}

output virtualNetworkId string = virtualNetwork.id
output masterSubnetId string = masterSubnet.id
output workerSubnetId string = workerSubnet.id
output privateEndpointSubnetId string = privateEndpointSubnet.id
output routeTableId string = routeTable.id
