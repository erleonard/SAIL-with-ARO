# ARO Landing-Zone Infrastructure Deployment Guide

This guide covers deploying the shared network foundation for the ARO cluster
that hosts Cohere North, using the PowerShell deployment script.

> ARO cluster provisioning and managed dependencies (Azure Database for
> PostgreSQL, Azure Cache for Redis, Key Vault) are added as separate templates.

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

## Automated GitHub Actions runner

The repository includes an approval-gated workflow that deploys one
repository-level self-hosted runner into an existing Azure subnet.

### One-time GitHub and Azure setup

1. Create a GitHub Environment named `runner-provisioning`.
2. Add required reviewers to the environment so deployments require approval.
3. Create a Microsoft Entra application or user-assigned managed identity with
   a federated credential for that environment. Use this subject:
   `repo:erleonard/SAIL-with-ARO:environment:runner-provisioning`.
4. Grant that identity permission to create the runner resource group and its
   resources, and permission to join the target subnet. For least privilege,
   scope the roles to the runner and network resource groups.
5. Define these GitHub Environment variables:
   - `AZURE_CLIENT_ID`
   - `AZURE_TENANT_ID`
   - `AZURE_SUBSCRIPTION_ID`

No GitHub personal access token is needed. The workflow grants its
`GITHUB_TOKEN` `actions: write` only long enough to request a short-lived
repository runner registration token.

### Network prerequisites

The target subnet must:

- Exist before the workflow runs.
- Have sufficient free addresses.
- Permit DNS and outbound HTTPS to GitHub, Ubuntu, and Microsoft package
  endpoints.
- Use NAT Gateway, Azure Firewall, or another explicit outbound method.

The template creates a private NIC only and does not modify the customer-owned
VNet, subnet, route table, or NSG. There is no public IP and no inbound access
rule. The generated SSH key is used only to satisfy Azure VM provisioning and
is discarded with the hosted workflow job.

### Provision the runner

Run **Actions > Provision Azure self-hosted runner > Run workflow** and supply:

- Azure region and runner resource group.
- VM name and size.
- Existing VNet resource group, VNet name, and subnet name.
- Comma-separated custom labels. Keep `sail-azure` when workflows rely on that
  label.

After the deployment completes, verify that the runner is online under
**Settings > Actions > Runners**. Jobs can target it with:

```yaml
runs-on: [self-hosted, sail-azure]
```

The bootstrap installs the GitHub Actions runner as a system service together
with Git, Azure CLI, Bicep, and PowerShell.

### Cleanup

Delete the VM resource group, then remove any offline runner entry under
**Settings > Actions > Runners**:

```powershell
az group delete --name rg-sail-runners --yes --no-wait
```

## Security Considerations

- Resources are deployed with private endpoints
- Resources are isolated within the virtual network
- Key Vault is used for secrets management
- Runner provisioning uses Azure OIDC rather than a stored Azure credential.
- The runner VM has a managed identity, automatic platform patching, Trusted
  Launch, and no public IP address.
