## Infrastructure as code for the ARO landing-zone foundation

This folder holds the Azure IaC that provisions the shared foundation for the
Azure Red Hat OpenShift (ARO) cluster that hosts Cohere North, with private
networking controls.

> Scope note: the previous Azure ML / Microsoft Foundry / Azure Databricks
> templates have been removed — Cohere North serves its own models on in-cluster
> GPU nodes and uses external Azure managed PostgreSQL and Redis. ARO cluster
> provisioning and the managed dependencies are tracked as separate templates.

## Current contents

- `aro.bicep` — subscription-scope entry point that creates the network and
  cluster resource groups and composes the ARO modules.
- `modules/aro/network.bicep` — ARO virtual network, dedicated control-plane and
  worker subnets, private-endpoint subnet, firewall UDR, and required VNet role
  assignments.
- `modules/aro/cluster.bicep` — private ARO cluster with FIPS enabled, three
  `Standard_D8s_v5` control-plane nodes and nine `Standard_D8s_v5` workers.
- `vnet.bicep` / `vnet.parameters.json` — virtual network (192.168.0.0/16) with a
  private-endpoint subnet (`pe-subnet`) used by managed dependencies (PostgreSQL,
  Redis, Key Vault). ARO master/worker subnets, route tables/UDRs and NSGs are
  added as part of the ARO networking work.
- `modules/dependent/keyvault.bicep` — Key Vault with private endpoint (used by
  the External Secrets Operator / Workload Identity integration).
- `modules/dependent/containerregistry.bicep` — container registry with private
  endpoint (optional image mirror for the Cohere OCI registries).
- `modules/dependent/applicationinsights.bicep` — Log Analytics workspace (log
  sink for the OpenShift cluster log forwarder).
- `modules/dependent/storage.bicep` — storage account with private endpoint
  (optional, for object-storage needs).
- `deploy.ps1` + `config.json` / `config.prod.json` — deployment orchestration
  and per-environment configuration.

See [DEPLOYMENT.md](DEPLOYMENT.md) for usage.

## ARO deployment

Register the required providers before the first deployment:

```bash
az provider register --namespace Microsoft.RedHatOpenShift --wait
az provider register --namespace Microsoft.Compute --wait
az provider register --namespace Microsoft.Storage --wait
az provider register --namespace Microsoft.Authorization --wait
```

Resolve the object ID of the Azure Red Hat OpenShift resource-provider service
principal, then deploy at subscription scope. Pass secrets from protected
environment variables so they are not stored in source files or shell history.

```powershell
$aroRpObjectId = az ad sp list --filter "appId eq 'f1dd0a37-89c6-4e07-bcd1-ffd3d43d8875'" --query '[0].id' -o tsv

az deployment sub create `
  --location canadaeast `
  --template-file aro.bicep `
  --parameters `
    location=canadaeast `
    clusterResourceGroupName=rg-sail-dev `
    networkResourceGroupName=rg-sail-network-dev `
    managedResourceGroupName=aro-sail-dev-canadaeast `
    clusterName=aro-sail-dev `
    domain=sail-dev `
    firewallPrivateIpAddress=$env:ARO_FIREWALL_PRIVATE_IP `
    servicePrincipalClientId=$env:ARO_SP_CLIENT_ID `
    servicePrincipalObjectId=$env:ARO_SP_OBJECT_ID `
    servicePrincipalClientSecret=$env:ARO_SP_CLIENT_SECRET `
    aroResourceProviderObjectId=$aroRpObjectId `
    pullSecret=$env:ARO_PULL_SECRET
```

The Azure ARO resource creates only the control plane and initial worker pool.
Create the three-node infra pool after cluster provisioning as an OpenShift
`MachineSet`, using the `infraMachineSetVmSize` output (`Standard_D8s_v5`). GPU
and OpenSearch pools remain separate post-provisioning work.

### Private DNS Zone Control

`createPrivateDnsZones` (default: `true`) controls private DNS zone creation for
private endpoints. Set to `false` for centralized/hub-spoke DNS or when zones
already exist.

```json
{
  "createPrivateDnsZones": false
}
```

## Manual Deployment

### Resource group(s) and virtual network

```bash
az group create --name <new-rg-name> --location <your-selected-region>
az group create --name <new-rg-name-vnet> --location <your-selected-region>
```

Deploy the virtual network:

```bash
az deployment group create --resource-group <new-rg-name-vnet> --template-file vnet.bicep --parameters vnet.parameters.json
```
