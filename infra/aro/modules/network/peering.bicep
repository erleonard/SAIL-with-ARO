@description('Name of the local virtual network')
param localVnetName string

@description('Resource ID of the remote virtual network')
param remoteVnetResourceId string

@description('Name of the virtual network peering')
param peeringName string

resource localVirtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: localVnetName
}

resource peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: localVirtualNetwork
  name: peeringName
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: remoteVnetResourceId
    }
  }
}

output peeringId string = peering.id
