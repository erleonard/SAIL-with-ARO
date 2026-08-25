targetScope = 'subscription'

@description('Azure region for the ARO deployment')
param location string

@description('Name of the resource group containing the ARO cluster')
param clusterResourceGroupName string

@description('Name of the resource group containing the ARO network')
param networkResourceGroupName string

@description('Name of the resource group managed by the ARO service')
param managedResourceGroupName string

@description('Name of the ARO cluster')
param clusterName string

@description('DNS domain prefix for the ARO cluster')
param domain string

@description('Name of the ARO virtual network')
param vnetName string = 'private-vnet'

@description('Object ID of the Azure Red Hat OpenShift resource-provider service principal')
param aroResourceProviderObjectId string

@description('Red Hat pull secret JSON')
@secure()
param pullSecret string

@description('OpenShift version. Leave empty to use the default supported version.')
param openShiftVersion string = ''

@description('Tags applied to resources')
param tags object = {}

resource networkResourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: networkResourceGroupName
  location: location
  tags: tags
}

resource clusterResourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: clusterResourceGroupName
  location: location
  tags: tags
}

module identities './modules/aro/identities.bicep' = {
  scope: clusterResourceGroup
  params: {
    location: location
  }
}

module network './modules/aro/network.bicep' = {
  scope: networkResourceGroup
  params: {
    location: location
    vnetName: vnetName
    operatorIdentityPrincipalIds: identities.outputs.operatorIdentityPrincipalIds
    aroResourceProviderObjectId: aroResourceProviderObjectId
    tags: tags
  }
}

module cluster './modules/aro/cluster.bicep' = {
  scope: clusterResourceGroup
  params: {
    location: location
    clusterName: clusterName
    domain: domain
    managedResourceGroupId: subscriptionResourceId('Microsoft.Resources/resourceGroups', managedResourceGroupName)
    masterSubnetId: network.outputs.masterSubnetId
    workerSubnetId: network.outputs.workerSubnetId
    clusterIdentityResourceId: identities.outputs.clusterIdentityResourceId
    operatorIdentityResourceIds: identities.outputs.operatorIdentityResourceIds
    pullSecret: pullSecret
    openShiftVersion: openShiftVersion
    tags: tags
  }
}

output clusterId string = cluster.outputs.clusterId
output virtualNetworkId string = network.outputs.virtualNetworkId
output privateEndpointSubnetId string = network.outputs.privateEndpointSubnetId
output firewallId string = network.outputs.firewallId
output firewallPrivateIpAddress string = network.outputs.firewallPrivateIpAddress
output nodeVmSize string = cluster.outputs.nodeVmSize
output infraMachineSetVmSize string = cluster.outputs.infraMachineSetVmSize
