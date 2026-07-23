# ARO Landing-Zone Infrastructure Deployment Guide

This guide covers deploying the shared network foundation for the ARO cluster
that hosts Cohere North, using the PowerShell deployment script.

> ARO cluster provisioning and managed dependencies (Azure Database for
> PostgreSQL, Azure Cache for Redis, Key Vault) are separate templates. The ARO
> cluster entry point is `aro.bicep`; `deploy.ps1` continues to deploy only the
> existing shared VNet foundation.

## Prerequisites

1. **Azure CLI**: Install from [https://docs.microsoft.com/cli/azure/install-azure-cli](https://docs.microsoft.com/cli/azure/install-azure-cli)
2. **PowerShell**: Version 7.0 or later recommended
3. **Azure Subscription**: Active Azure subscription with appropriate permissions
4. **Login to Azure**: Run `az login` before deployment

## Quick Start

### 1. Login to Azure

```powershell
az login
```

### 2. Configure Your Deployment

Edit the `config.json` file with your specific values:

```json
{
  "location": "canadaeast",
  "resourceGroup": "rg-sail-dev",
  "vnetResourceGroup": "rg-sail-network-dev",
  "vnetName": "private-vnet",
  "subnetName": "pe-subnet",
  "createPrivateDnsZones": false
}
```

### 3. Deploy

```powershell
.\deploy.ps1
```

This will deploy:
- Virtual Network with a private-endpoint subnet

## Advanced Usage

### Deploy the private ARO cluster

Use the subscription-scope `aro.bicep` entry point to deploy the ARO network
and cluster modules. It requires the Protected B firewall private IP, ARO
service-principal client and object IDs, client secret, Red Hat pull secret, and
the ARO resource-provider service-principal object ID. See [README.md](README.md)
for the complete command.

The deployment standardizes the control-plane and initial worker nodes on
`Standard_D8s_v5`. Create the infra pool afterward as an OpenShift `MachineSet`
with three `Standard_D8s_v5` nodes.

### Deploy only the VNet

```powershell
.\deploy.ps1 -DeploymentType vnet
```

### Use Different Configuration Files

```powershell
.\deploy.ps1 -ConfigFile .\config.prod.json
```

### Specify Subscription

```powershell
.\deploy.ps1 -SubscriptionId "your-subscription-id"
```

### Skip VNet Deployment (if VNet already exists)

```powershell
.\deploy.ps1 -SkipVNetDeployment
```

## Configuration Files

- **config.json** — development configuration.
- **config.prod.json** — production configuration template.
- **vnet.parameters.json** — static parameters for VNet deployment.

## Deployment Architecture

The script deploys resources in the following order:

1. **Resource Groups**
   - VNet resource group (e.g., `rg-sail-network-dev`)
   - Main resource group (e.g., `rg-sail-dev`)

2. **Virtual Network** (unless skipped)
   - Private virtual network (192.168.0.0/16)
   - Private endpoint subnet (192.168.0.0/24)

## Troubleshooting

### Azure CLI Not Found
```powershell
az version
```

### Authentication Errors
```powershell
az login
az account show
az account list --output table
```

### Resource Group Already Exists
The script will use existing resource groups if they already exist. This is by design.

### VNet Already Exists
Use the `-SkipVNetDeployment` flag to skip VNet creation.

### Permission Errors
Ensure your Azure account has:
- Contributor role on the subscription or resource group
- Permissions to create resource groups
- Permissions to create network resources and private endpoints

## Cleanup

```powershell
az group delete --name rg-sail-dev --yes --no-wait
az group delete --name rg-sail-network-dev --yes --no-wait
```

## Security Considerations

- Resources are deployed with private endpoints
- Resources are isolated within the virtual network
- Key Vault is used for secrets management
