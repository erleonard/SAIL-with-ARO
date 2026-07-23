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

@description('Object ID of the ARO service principal')
param servicePrincipalObjectId string

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

resource servicePrincipalVnetContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(virtualNetwork.id, servicePrincipalObjectId, 'contributor')
  scope: virtualNetwork
  properties: {
    principalId: servicePrincipalObjectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
  }
}

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
