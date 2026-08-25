@description('Azure region for hub network resources')
param location string = resourceGroup().location

@description('Name of the hub virtual network')
param hubVnetName string

@description('Hub virtual network address space')
param hubAddressPrefix string = '10.0.0.0/16'

@description('Azure Firewall subnet address prefix')
param firewallSubnetPrefix string = '10.0.0.0/26'

@description('GitHub Self-Hosted Runner subnet address prefix')
param ghrunnerSubnetPrefix string = '10.0.1.0/24'

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

var entraLoginFqdn = replace(replace(environment().authentication.loginEndpoint, 'https://', ''), '/', '')

resource hubVirtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: hubVnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        hubAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: firewallSubnetPrefix
        }
      }
      {
        name: 'GHRunnerSubnet'
        properties: {
          addressPrefix: ghrunnerSubnetPrefix
        }
      }
    ]
  }
}

resource firewallSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: hubVirtualNetwork
  name: 'AzureFirewallSubnet'
}

resource firewallPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: firewallPublicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

resource firewallPolicy 'Microsoft.Network/firewallPolicies@2024-05-01' = {
  name: firewallPolicyName
  location: location
  tags: tags
  properties: {
    sku: {
      tier: 'Standard'
    }
    threatIntelMode: 'Alert'
    dnsSettings: {
      enableProxy: true
    }
  }
}

resource aroEgressRules 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = {
  parent: firewallPolicy
  name: 'aro-egress'
  properties: {
    priority: 200
    ruleCollections: [
      {
        name: 'aro-platform-egress'
        priority: 200
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            name: 'allow-aro-platform-https'
            ruleType: 'ApplicationRule'
            sourceAddresses: [
              spokeAddressPrefix
            ]
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            targetFqdns: [
              entraLoginFqdn
              'graph.microsoft.com'
              'registry.redhat.io'
              'quay.io'
              '*.quay.io'
              'access.redhat.com'
              'registry.access.redhat.com'
              'registry.connect.redhat.com'
              'api.openshift.com'
              'mirror.openshift.com'
            ]
          }
        ]
      }
    ]
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2024-05-01' = {
  name: firewallName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    firewallPolicy: {
      id: firewallPolicy.id
    }
    ipConfigurations: [
      {
        name: 'firewallIpConfiguration'
        properties: {
          subnet: {
            id: firewallSubnet.id
          }
          publicIPAddress: {
            id: firewallPublicIp.id
          }
        }
      }
    ]
  }
}

output virtualNetworkId string = hubVirtualNetwork.id
output virtualNetworkName string = hubVirtualNetwork.name
output firewallId string = firewall.id
output firewallPrivateIpAddress string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
output firewallPolicyId string = firewallPolicy.id
