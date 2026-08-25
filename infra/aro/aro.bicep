targetScope = 'subscription'

@description('Azure region for the ARO cluster deployment')
param location string

@description('Name of the resource group containing the ARO cluster')
param clusterResourceGroupName string

@description('Name of the resource group managed by the ARO service')
param managedResourceGroupName string

@description('Name of the ARO cluster')
param clusterName string

@description('DNS domain prefix for the ARO cluster')
param domain string

@description('Name of the ARO spoke virtual network')
param spokeVnetName string

@description('Name of the control-plane subnet')
param masterSubnetName string = 'master-subnet'

@description('Name of the worker subnet')
param workerSubnetName string = 'worker-subnet'

@description('Name of the private-endpoint subnet')
param privateEndpointSubnetName string = 'pe-subnet'

@description('Name of the route table attached to ARO subnets')
param routeTableName string = 'aro-route-table'

@description('Object ID of the Azure Red Hat OpenShift resource-provider service principal')
param aroResourceProviderObjectId string

@description('Red Hat pull secret JSON')
@secure()
param pullSecret string

@description('OpenShift version. Leave empty to use the default supported version.')
param openShiftVersion string = ''

@description('Tags applied to resources')
param tags object = {}

resource clusterResourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' existing = {
  name: clusterResourceGroupName
}

resource spokeVirtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  scope: clusterResourceGroup
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

resource privateEndpointSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: spokeVirtualNetwork
  name: privateEndpointSubnetName
}

module identities './modules/aro/identities.bicep' = {
  scope: clusterResourceGroup
  params: {
    location: location
  }
}

module networkRoleAssignments './modules/aro/network-role-assignments.bicep' = {
  scope: clusterResourceGroup
  params: {
    spokeVnetName: spokeVnetName
    masterSubnetName: masterSubnetName
    workerSubnetName: workerSubnetName
    routeTableName: routeTableName
    operatorIdentityPrincipalIds: identities.outputs.operatorIdentityPrincipalIds
    aroResourceProviderObjectId: aroResourceProviderObjectId
  }
}

module cluster './modules/aro/cluster.bicep' = {
  scope: clusterResourceGroup
  params: {
    location: location
    clusterName: clusterName
    domain: domain
    managedResourceGroupId: subscriptionResourceId('Microsoft.Resources/resourceGroups', managedResourceGroupName)
    masterSubnetId: masterSubnet.id
    workerSubnetId: workerSubnet.id
    clusterIdentityResourceId: identities.outputs.clusterIdentityResourceId
    operatorIdentityResourceIds: identities.outputs.operatorIdentityResourceIds
    pullSecret: pullSecret
    openShiftVersion: openShiftVersion
    tags: tags
  }
  dependsOn: [
    networkRoleAssignments
  ]
}

output clusterId string = cluster.outputs.clusterId
output virtualNetworkId string = spokeVirtualNetwork.id
output privateEndpointSubnetId string = privateEndpointSubnet.id
output nodeVmSize string = cluster.outputs.nodeVmSize
output infraMachineSetVmSize string = cluster.outputs.infraMachineSetVmSize
