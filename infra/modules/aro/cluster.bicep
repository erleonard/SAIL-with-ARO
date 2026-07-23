@description('Azure region for the ARO cluster')
param location string = resourceGroup().location

@description('Name of the ARO cluster')
param clusterName string

@description('DNS domain prefix for the ARO cluster')
param domain string

@description('Resource ID of the ARO-managed resource group')
param managedResourceGroupId string

@description('Resource ID of the control-plane subnet')
param masterSubnetId string

@description('Resource ID of the worker subnet')
param workerSubnetId string

@description('Application (client) ID of the ARO service principal')
param servicePrincipalClientId string

@description('Object ID of the ARO service principal')
param servicePrincipalObjectId string

@description('Client secret of the ARO service principal')
@secure()
param servicePrincipalClientSecret string

@description('Red Hat pull secret JSON')
@secure()
param pullSecret string

@description('OpenShift version. Leave empty to use the default supported version.')
param openShiftVersion string = ''

@description('Pod network CIDR; it must not overlap the VNet or connected networks')
param podCidr string = '10.128.0.0/14'

@description('Service network CIDR; it must not overlap the VNet or connected networks')
param serviceCidr string = '172.30.0.0/16'

@description('OS disk size in GiB for standard worker nodes')
@minValue(200)
param workerDiskSizeGB int = 200

@description('Number of standard worker nodes')
@minValue(3)
param workerCount int = 9

@description('Tags applied to the ARO cluster')
param tags object = {}

var nodeVmSize = 'Standard_D8s_v5'
var clusterProfile = union({
  domain: domain
  resourceGroupId: managedResourceGroupId
  pullSecret: pullSecret
  fipsValidatedModules: 'Enabled'
}, empty(openShiftVersion) ? {} : {
  version: openShiftVersion
})

resource servicePrincipalContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, servicePrincipalObjectId, 'contributor')
  properties: {
    principalId: servicePrincipalObjectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
  }
}

resource servicePrincipalUserAccessAdministrator 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, servicePrincipalObjectId, 'user-access-administrator')
  properties: {
    principalId: servicePrincipalObjectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '18d7d88d-d35e-4627-90cd-7e149e0a5d4f')
  }
}

resource cluster 'Microsoft.RedHatOpenShift/openShiftClusters@2025-07-25' = {
  name: clusterName
  location: location
  tags: tags
  properties: {
    clusterProfile: clusterProfile
    networkProfile: {
      podCidr: podCidr
      serviceCidr: serviceCidr
      outboundType: 'UserDefinedRouting'
    }
    servicePrincipalProfile: {
      clientId: servicePrincipalClientId
      clientSecret: servicePrincipalClientSecret
    }
    masterProfile: {
      vmSize: nodeVmSize
      subnetId: masterSubnetId
    }
    workerProfiles: [
      {
        name: 'worker'
        vmSize: nodeVmSize
        diskSizeGB: workerDiskSizeGB
        subnetId: workerSubnetId
        count: workerCount
      }
    ]
    apiserverProfile: {
      visibility: 'Private'
    }
    ingressProfiles: [
      {
        name: 'default'
        visibility: 'Private'
      }
    ]
  }
  dependsOn: [
    servicePrincipalContributor
    servicePrincipalUserAccessAdministrator
  ]
}

output clusterId string = cluster.id
output clusterName string = cluster.name
output nodeVmSize string = nodeVmSize
output infraMachineSetVmSize string = nodeVmSize
