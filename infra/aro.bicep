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

@description('Private IP address of the Protected B firewall used for outbound traffic')
param firewallPrivateIpAddress string

@description('Application (client) ID of the ARO service principal')
param servicePrincipalClientId string

@description('Object ID of the ARO service principal')
param servicePrincipalObjectId string

@description('Client secret of the ARO service principal')
@secure()
param servicePrincipalClientSecret string

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

module network './modules/aro/network.bicep' = {
  scope: networkResourceGroup
  params: {
    location: location
    vnetName: vnetName
    firewallPrivateIpAddress: firewallPrivateIpAddress
    servicePrincipalObjectId: servicePrincipalObjectId
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
    servicePrincipalClientId: servicePrincipalClientId
    servicePrincipalObjectId: servicePrincipalObjectId
    servicePrincipalClientSecret: servicePrincipalClientSecret
    pullSecret: pullSecret
    openShiftVersion: openShiftVersion
    tags: tags
  }
}

output clusterId string = cluster.outputs.clusterId
output virtualNetworkId string = network.outputs.virtualNetworkId
output privateEndpointSubnetId string = network.outputs.privateEndpointSubnetId
output nodeVmSize string = cluster.outputs.nodeVmSize
output infraMachineSetVmSize string = cluster.outputs.infraMachineSetVmSize
