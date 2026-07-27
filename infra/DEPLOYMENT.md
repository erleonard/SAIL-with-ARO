# ARO Landing-Zone Infrastructure Deployment Guide

This guide covers deploying the shared network foundation and ARO cluster that
hosts Cohere North, using the PowerShell deployment script. Managed dependencies
(Azure Database for PostgreSQL, Azure Cache for Redis, and Key Vault) remain
separate templates.

## Prerequisites

1. **Azure CLI**: Install from [https://docs.microsoft.com/cli/azure/install-azure-cli](https://docs.microsoft.com/cli/azure/install-azure-cli)
2. **PowerShell**: Version 7.0 or later recommended
3. **Azure Subscription**: Active Azure subscription with appropriate permissions
4. **Login to Azure**: Run `az login` before deployment
5. **Protected B firewall**: An existing firewall private IP for ARO egress
6. **Red Hat pull secret**: A pull secret from the Red Hat Hybrid Cloud Console

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
   "managedResourceGroupName": "aro-sail-dev-canadaeast",
   "clusterName": "aro-sail-dev",
   "domain": "sail-dev",
  "vnetName": "private-vnet",
  "subnetName": "pe-subnet",
  "createPrivateDnsZones": false
}
```

### 3. Set protected inputs

```powershell
$env:ARO_FIREWALL_PRIVATE_IP = az network firewall show `
   --resource-group '<firewall-resource-group>' `
   --name '<firewall-name>' `
   --query 'ipConfigurations[0].privateIPAddress' `
   --output tsv
$env:ARO_PULL_SECRET = Get-Content .\pull-secret.txt -Raw
```

Replace the firewall resource group and name placeholders in the lookup command.
The environment variable must contain the resulting private IPv4 address, such
as `10.0.1.4`; do not assign the text `<firewall-private-ip>`.

### 4. Deploy

```powershell
.\deploy.ps1
```

This will deploy:
- Virtual Network with a private-endpoint subnet
- ARO network with firewall routing and private control-plane/worker subnets
- Nine user-assigned managed identities and their required role assignments
- Private ARO cluster

## Advanced Usage

### Deploy the private ARO cluster

Use the `aro` deployment type to deploy the ARO network and cluster without
running the legacy private-endpoint VNet deployment. The script resolves the ARO
resource-provider identity automatically.

```powershell
.\deploy.ps1 -DeploymentType aro
```

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

### Skip the legacy VNet deployment

```powershell
.\deploy.ps1 -SkipVNetDeployment
```

With `-DeploymentType all`, this flag skips `vnet.bicep` but still deploys the
ARO network and cluster through `aro.bicep`.

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

3. **ARO network, identities, and cluster** (`all` or `aro`)
   - Firewall UDR and private ARO subnets
   - Nine user-assigned managed identities with operator-specific RBAC
   - Private ARO cluster

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
- Contributor and User Access Administrator roles, or Owner, on the subscription
- Permissions to create resource groups
- Permissions to query the ARO resource-provider enterprise application

## Cleanup

```powershell
az group delete --name rg-sail-dev --yes --no-wait
az group delete --name rg-sail-network-dev --yes --no-wait
```

## Security Considerations

- Resources are deployed with private endpoints
- Resources are isolated within the virtual network
- Key Vault is used for secrets management
