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

@description('Resource ID of the ARO cluster managed identity')
param clusterIdentityResourceId string

@description('Resource IDs of the ARO platform workload identities')
param operatorIdentityResourceIds object

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

resource cluster 'Microsoft.RedHatOpenShift/openShiftClusters@2025-07-25' = {
  name: clusterName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${clusterIdentityResourceId}': {}
    }
  }
  properties: {
    clusterProfile: clusterProfile
    networkProfile: {
      podCidr: podCidr
      serviceCidr: serviceCidr
      outboundType: 'UserDefinedRouting'
    }
    platformWorkloadIdentityProfile: {
      platformWorkloadIdentities: {
        'cloud-controller-manager': {
          resourceId: operatorIdentityResourceIds.cloudControllerManager
        }
        ingress: {
          resourceId: operatorIdentityResourceIds.ingress
        }
        'machine-api': {
          resourceId: operatorIdentityResourceIds.machineApi
        }
        'disk-csi-driver': {
          resourceId: operatorIdentityResourceIds.diskCsiDriver
        }
        'cloud-network-config': {
          resourceId: operatorIdentityResourceIds.cloudNetworkConfig
        }
        'image-registry': {
          resourceId: operatorIdentityResourceIds.imageRegistry
        }
        'file-csi-driver': {
          resourceId: operatorIdentityResourceIds.fileCsiDriver
        }
        'aro-operator': {
          resourceId: operatorIdentityResourceIds.aroOperator
        }
      }
    }
    masterProfile: {
      vmSize: nodeVmSize
      subnetId: masterSubnetId
      encryptionAtHost: 'Disabled'
    }
    workerProfiles: [
      {
        name: 'worker'
        vmSize: nodeVmSize
        diskSizeGB: workerDiskSizeGB
        subnetId: workerSubnetId
        count: workerCount
        encryptionAtHost: 'Disabled'
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
}

output clusterId string = cluster.id
output clusterName string = cluster.name
output nodeVmSize string = nodeVmSize
output infraMachineSetVmSize string = nodeVmSize
