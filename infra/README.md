## Infrastructure as code for the ARO landing-zone foundation

This folder holds the Azure IaC that provisions the shared foundation for the
Azure Red Hat OpenShift (ARO) cluster that hosts Cohere North, with private
networking controls.

> Scope note: the previous Azure ML / Microsoft Foundry / Azure Databricks
> templates have been removed — Cohere North serves its own models on in-cluster
> GPU nodes and uses external Azure managed PostgreSQL and Redis. ARO cluster
> provisioning and the managed dependencies are tracked as separate templates.

## Current contents

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
