@description('Azure region for the ARO spoke network')
param location string = resourceGroup().location

@description('Name of the ARO spoke virtual network')
param spokeVnetName string

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

@description('Name of the route table attached to the ARO subnets')
param routeTableName string = 'aro-route-table'

@description('Resource ID of the hub virtual network')
param hubVnetResourceId string

@description('Private IP address of the hub firewall or network virtual appliance')
param hubNextHopIpAddress string

@description('Tags applied to spoke network resources')
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
  name: 'default-via-hub'
  properties: {
    addressPrefix: '0.0.0.0/0'
    nextHopType: 'VirtualAppliance'
    nextHopIpAddress: hubNextHopIpAddress
  }
}

resource spokeVirtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: spokeVnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        spokeAddressPrefix
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

resource spokeToHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: spokeVirtualNetwork
  name: 'to-hub'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: hubVnetResourceId
    }
  }
}

output virtualNetworkId string = spokeVirtualNetwork.id
output masterSubnetId string = masterSubnet.id
output workerSubnetId string = workerSubnet.id
output privateEndpointSubnetId string = privateEndpointSubnet.id
output routeTableId string = routeTable.id
output peeringId string = spokeToHubPeering.id
