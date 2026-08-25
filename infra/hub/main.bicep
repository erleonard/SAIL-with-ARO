targetScope = 'subscription'

@description('Azure region for hub network resources')
param location string

@description('Name of the hub network resource group')
param resourceGroupName string

@description('Name of the hub virtual network')
param vnetName string

@description('Hub virtual network address space')
param addressPrefix string = '10.0.0.0/16'

@description('Azure Firewall subnet address prefix')
param firewallSubnetPrefix string = '10.0.0.0/26'

@description('Name of the Azure Firewall')
param firewallName string = 'aro-hub-firewall'

@description('Name of the Azure Firewall public IP address')
param firewallPublicIpName string = 'aro-hub-firewall-pip'

@description('Name of the Azure Firewall Policy')
param firewallPolicyName string = 'aro-hub-firewall-policy'

@description('Address space of the ARO spoke allowed through the firewall')
param spokeAddressPrefix string = '10.1.0.0/16'

@description('Tags applied to hub network resources')
param tags object = {}

resource hubResourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module hub './modules/network/hub.bicep' = {
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
    hubVnetName: vnetName
    hubAddressPrefix: addressPrefix
    firewallSubnetPrefix: firewallSubnetPrefix
    firewallName: firewallName
    firewallPublicIpName: firewallPublicIpName
    firewallPolicyName: firewallPolicyName
    spokeAddressPrefix: spokeAddressPrefix
    tags: tags
  }
  dependsOn: [
    hubResourceGroup
  ]
}

output virtualNetworkId string = hub.outputs.virtualNetworkId
output firewallPrivateIpAddress string = hub.outputs.firewallPrivateIpAddress
output firewallId string = hub.outputs.firewallId
output firewallPolicyId string = hub.outputs.firewallPolicyId
