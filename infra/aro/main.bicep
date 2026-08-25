targetScope = 'subscription'

@description('Azure region for deployed resources')
param location string

@description('Deployment stage to run')
@allowed([
  'all'
  'spoke'
  'aro'
])
param deploymentType string = 'all'

@description('Subscription ID containing the hub VNet')
param hubSubscriptionId string = subscription().subscriptionId

@description('Name of the hub network resource group')
param hubResourceGroupName string = ''

@description('Name of the hub virtual network')
param hubVnetName string = ''

@description('Resource ID of the separately deployed hub VNet; derived from its subscription, resource group, and name when empty')
param hubVnetResourceId string = ''

@description('Private IP address of an existing hub firewall or network virtual appliance')
param hubNextHopIpAddress string = ''

@description('Name of the ARO spoke virtual network')
param spokeVnetName string = 'sail-spoke-vnet'

@description('ARO spoke virtual network address space')
param spokeAddressPrefix string = '10.1.0.0/16'

@description('Name of the control-plane subnet')
param masterSubnetName string = 'master-subnet'

@description('Control-plane subnet address prefix')
param masterSubnetPrefix string = '10.1.2.0/24'

@description('Name of the worker subnet')
param workerSubnetName string = 'worker-subnet'

@description('Worker subnet address prefix')
param workerSubnetPrefix string = '10.1.4.0/23'

@description('Name of the private-endpoint subnet')
param privateEndpointSubnetName string = 'pe-subnet'

@description('Private-endpoint subnet address prefix')
param privateEndpointSubnetPrefix string = '10.1.0.0/24'

@description('Name of the route table attached to ARO subnets')
param routeTableName string = 'aro-route-table'

@description('Name of the resource group containing the ARO cluster')
param clusterResourceGroupName string = ''

@description('Name of the resource group managed by the ARO service')
param managedResourceGroupName string = ''

@description('Name of the ARO cluster')
param clusterName string = ''

@description('DNS domain prefix for the ARO cluster')
param domain string = ''

@description('Object ID of the Azure Red Hat OpenShift resource-provider service principal')
param aroResourceProviderObjectId string = ''

@description('Red Hat pull secret JSON; required for all and aro deployments')
@secure()
param pullSecret string = ''

@description('OpenShift version. Leave empty to use the default supported version.')
param openShiftVersion string = ''

@description('Tags applied to deployed resources')
param tags object = {}

var deploySpoke = deploymentType == 'spoke' || deploymentType == 'all'
var deployAro = deploymentType == 'aro' || deploymentType == 'all'
var configuredHubVnetResourceId = empty(hubVnetResourceId)
  ? resourceId(hubSubscriptionId, hubResourceGroupName, 'Microsoft.Network/virtualNetworks', hubVnetName)
  : hubVnetResourceId

resource clusterResourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = if (deploySpoke || deployAro) {
  name: clusterResourceGroupName
  location: location
  tags: tags
}

module spoke './modules/network/spoke.bicep' = if (deploySpoke) {
  scope: resourceGroup(clusterResourceGroupName)
  params: {
    location: location
    spokeVnetName: spokeVnetName
    spokeAddressPrefix: spokeAddressPrefix
    masterSubnetName: masterSubnetName
    masterSubnetPrefix: masterSubnetPrefix
    workerSubnetName: workerSubnetName
    workerSubnetPrefix: workerSubnetPrefix
    privateEndpointSubnetName: privateEndpointSubnetName
    privateEndpointSubnetPrefix: privateEndpointSubnetPrefix
    routeTableName: routeTableName
    hubVnetResourceId: configuredHubVnetResourceId
    hubNextHopIpAddress: hubNextHopIpAddress
    tags: tags
  }
  dependsOn: [
    clusterResourceGroup
  ]
}

module hubToSpokePeering './modules/network/peering.bicep' = if (deploySpoke) {
  scope: resourceGroup(hubSubscriptionId, hubResourceGroupName)
  params: {
    localVnetName: hubVnetName
    remoteVnetResourceId: spoke!.outputs.virtualNetworkId
    peeringName: 'to-${spokeVnetName}'
  }
}

module aro './aro.bicep' = if (deployAro) {
  params: {
    location: location
    clusterResourceGroupName: clusterResourceGroupName
    managedResourceGroupName: managedResourceGroupName
    clusterName: clusterName
    domain: domain
    spokeVnetName: spokeVnetName
    masterSubnetName: masterSubnetName
    workerSubnetName: workerSubnetName
    privateEndpointSubnetName: privateEndpointSubnetName
    routeTableName: routeTableName
    aroResourceProviderObjectId: aroResourceProviderObjectId
    pullSecret: pullSecret
    openShiftVersion: openShiftVersion
    tags: tags
  }
  dependsOn: [
    clusterResourceGroup
    spoke
    hubToSpokePeering
  ]
}

output hubVirtualNetworkId string = deploySpoke ? configuredHubVnetResourceId : ''
output hubFirewallPrivateIpAddress string = hubNextHopIpAddress
output clusterId string = deployAro ? aro!.outputs.clusterId : ''
