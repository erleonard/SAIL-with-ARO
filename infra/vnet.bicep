/*
  Generic virtual network and subnet

  Description:
  - Virtual network
  - Subnet for private endpoints (managed PostgreSQL, Redis, Key Vault, etc.)

  Note: ARO control-plane (master) and worker subnets, route tables/UDRs, and
  NSGs are added separately as part of the ARO networking work.
*/

@description('Name of the virtual network')
param vnetName string = 'private-vnet'

@description('Name of the private endpoint subnet')
param peSubnetName string = 'pe-subnet'

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '192.168.0.0/16'
      ]
    }
    subnets: [
      {
        name: peSubnetName
        properties: {
          addressPrefix: '192.168.0.0/24'
        }
      }
    ]
  }
}
