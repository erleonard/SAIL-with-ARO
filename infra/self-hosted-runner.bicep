targetScope = 'resourceGroup'

@description('Azure region for the runner resources')
param location string = resourceGroup().location

@description('Name used for both the Azure VM and the GitHub runner')
@minLength(1)
@maxLength(64)
param vmName string = 'sail-github-runner'

@description('Azure VM size')
param vmSize string = 'Standard_D2s_v5'

@description('Resource group containing the existing virtual network')
param vnetResourceGroupName string

@description('Name of the existing virtual network')
param vnetName string

@description('Name of the existing subnet for the runner')
param subnetName string

@description('Linux administrator username')
param adminUsername string = 'sailrunner'

@description('SSH public key used to satisfy Azure VM authentication requirements')
param adminSshPublicKey string

@description('Repository URL used to register the GitHub runner')
param runnerUrl string

@secure()
@description('Short-lived GitHub runner registration token')
param runnerRegistrationToken string

@description('Comma-separated custom runner labels')
param runnerLabels string = 'sail-azure'

@secure()
@description('Base64-encoded runner bootstrap script')
param bootstrapScriptBase64 string

@description('Tags applied to the runner resources')
param tags object = {}

@description('Value that causes the bootstrap extension to run again on each deployment')
param bootstrapRunId string = utcNow()

resource existingVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: vnetName
  scope: resourceGroup(vnetResourceGroupName)
}

resource existingSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: existingVnet
  name: subnetName
}

resource runnerNic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${vmName}-nic'
  location: location
  tags: tags
  properties: {
    enableAcceleratedNetworking: false
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: existingSubnet.id
          }
        }
      }
    ]
  }
}

resource runnerVm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: runnerNic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        provisionVMAgent: true
        patchSettings: {
          assessmentMode: 'AutomaticByPlatform'
          patchMode: 'AutomaticByPlatform'
        }
        ssh: {
          publicKeys: [
            {
              keyData: adminSshPublicKey
              path: '/home/${adminUsername}/.ssh/authorized_keys'
            }
          ]
        }
      }
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
    storageProfile: {
      imageReference: {
        offer: 'ubuntu-24_04-lts'
        publisher: 'Canonical'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        deleteOption: 'Delete'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        osType: 'Linux'
      }
    }
  }
}

var bootstrapCommand = 'echo \'${bootstrapScriptBase64}\' | base64 --decode > /tmp/bootstrap-github-runner.sh && chmod 700 /tmp/bootstrap-github-runner.sh && RUNNER_URL_B64=\'${base64(runnerUrl)}\' RUNNER_TOKEN_B64=\'${base64(runnerRegistrationToken)}\' RUNNER_LABELS_B64=\'${base64(runnerLabels)}\' RUNNER_NAME_B64=\'${base64(vmName)}\' /tmp/bootstrap-github-runner.sh && rm -f /tmp/bootstrap-github-runner.sh'

resource runnerBootstrap 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: runnerVm
  name: 'bootstrap-github-runner'
  location: location
  properties: {
    autoUpgradeMinorVersion: true
    forceUpdateTag: bootstrapRunId
    protectedSettings: {
      commandToExecute: '/bin/bash -c "${replace(bootstrapCommand, '"', '\\"')}"'
    }
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
  }
}

output privateIpAddress string = runnerNic.properties.ipConfigurations[0].properties.privateIPAddress
output runnerName string = runnerVm.name
output runnerPrincipalId string = runnerVm.identity.principalId
