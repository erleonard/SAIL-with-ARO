## Infrastructure as code for the ARO landing-zone foundation

This folder holds the Azure IaC that provisions the shared foundation for the
Azure Red Hat OpenShift (ARO) cluster that hosts Cohere North, with private
networking controls.

> Scope note: the previous Azure ML / Microsoft Foundry / Azure Databricks
> templates have been removed — Cohere North serves its own models on in-cluster
> GPU nodes and uses external Azure managed PostgreSQL and Redis. ARO cluster
> provisioning and the managed dependencies are tracked as separate templates.

## Current contents

- `hub/main.bicep` — independent subscription-scope deployment for the hub
  resource group, VNet, Azure Firewall, public IP, Firewall Policy, and egress
  rules.
- `hub/main.bicepparam` — deployment values for the independent hub deployment.
- `aro/main.bicep` — subscription-scope orchestrator for the `spoke`, `aro`, and
  `all` deployment stages. It consumes a previously deployed or externally
  managed hub VNet.
- `aro/main.bicepparam` — deployment values for manual and native GitHub Actions
  spoke/ARO deployments; the protected pull secret comes from an environment
  variable.
- `modules/network/hub.bicep` — hub VNet, Azure Firewall, Standard public IP,
  Firewall Policy, and ARO platform egress rules.
- `aro/modules/network/spoke.bicep` — ARO spoke VNet, control-plane, worker, and
  private-endpoint subnets, default route to the hub, and spoke-side peering.
  The `sail-spoke-vnet` VNet uses `10.1.0.0/16` and is deployed into the ARO
  resource group.
- `aro/modules/network/peering.bicep` — hub-side peering, including same-tenant
  cross-subscription BYO hubs.
- `aro/aro.bicep` — cluster-only composition of ARO identities, network RBAC, and
  the ARO resource on an existing spoke.
- `aro/modules/aro/cluster.bicep` — private ARO cluster with user-defined routing,
  FIPS enabled, three
  `Standard_D8s_v5` control-plane nodes, and three `Standard_D8s_v5` workers.
- `aro/modules/aro/network-role-assignments.bicep` — ARO operator and
  resource-provider roles on the existing spoke network.
- `aro/machinesets/infra-machineset.yaml` — post-deployment OpenShift manifest
  for a three-node infrastructure MachineSet.
- `deploy.ps1` + `config.json` / `config.prod.json` — deployment orchestration
  and per-environment configuration.
- `configure-entra-auth.ps1` — idempotent post-provisioning configuration for
  Microsoft Entra ID login through the OpenShift OAuth server.

See [DEPLOYMENT.md](DEPLOYMENT.md) for usage.

## ARO deployment

Register the required providers before the first deployment:

```bash
az provider register --namespace Microsoft.RedHatOpenShift --wait
az provider register --namespace Microsoft.Compute --wait
az provider register --namespace Microsoft.Storage --wait
az provider register --namespace Microsoft.Authorization --wait
```

Deploy the hub independently before creating the ARO spoke:

```powershell
az deployment sub create `
  --location swedencentral `
  --template-file ./hub/main.bicep `
  --parameters ./hub/main.bicepparam
```

The spoke deployment consumes the hub VNet and firewall private IP configured in
`aro/main.bicepparam`:

```powershell
az deployment sub create `
  --location swedencentral `
  --template-file ./aro/main.bicep `
  --parameters ./aro/main.bicepparam deploymentType=spoke
```

The cluster stage requires the spoke, route table, and both peerings to exist:

```powershell
$env:ARO_PULL_SECRET = Get-Content ./pull-secret.txt -Raw
az deployment sub create `
  --location swedencentral `
  --template-file ./aro/main.bicep `
  --parameters ./aro/main.bicepparam deploymentType=aro
```

## GitHub Actions deployment

The manually triggered
[`Deploy ARO`](../.github/workflows/deploy-aro.yml) workflow runs the same
deployment script with GitHub OpenID Connect (OIDC) authentication. Select
`infra/config.json` or `infra/config.prod.json` when starting the workflow. The
default `aro` stage expects the network foundation to exist; select `all` for a
new end-to-end environment. A successful ARO deployment starts a separate Entra
integration job when `entraId.enabled` is `true`. That job performs a new OIDC
sign-in so it does not reuse credentials from the long-running infrastructure
deployment. Both jobs run only on a self-hosted GitHub Actions runner. The
runner must have network access to the private ARO environment and have
PowerShell 7 and Azure CLI installed.

Define these repository or organization secrets:

- `AZURE_CLIENT_ID` — application/client ID of the deployment identity.
- `AZURE_TENANT_ID` — Microsoft Entra tenant ID.
- `AZURE_SUBSCRIPTION_ID` — target Azure subscription ID.
- `ARO_PULL_SECRET` — complete Red Hat pull-secret JSON.
- `ARO_ENTRA_CLIENT_SECRET` — optional existing Entra application credential.

Configure a federated credential on the deployment identity for the branch or
tag that will run this workflow. GitHub OIDC tokens for repositories using
immutable subjects include the owner and repository IDs. For this repository,
a workflow running from the `main` branch uses the subject
`repo:erleonard@10328520/SAIL-with-ARO-private@1333421520:ref:refs/heads/main`.
Grant the identity the Azure permissions required by the templates, including
permission to create role assignments, register resource providers, and manage
networking when using a BYO hub. The identity must also be able to read the ARO
resource-provider service principal from Microsoft Entra ID.

Run the workflow from **Actions > Deploy ARO > Run workflow**, select the target
configuration and deployment stage. Deployments using the same configuration
are serialized. Spoke-only runs do not start the Entra job.

The manually triggered
[`Deploy Hub network`](../.github/workflows/deploy-hub.yml) workflow deploys the
independent `hub/` template and parameter file on a GitHub-hosted runner. Run it
before the spoke workflow when this project owns the hub.

The manually triggered
[`Deploy ARO with native Azure CLI`](../.github/workflows/deploy-aro-native.yml)
workflow is an alternative that does not call `deploy.ps1` or read infrastructure
values from `config.json`. `aro/main.bicepparam` defines the target environment;
update that file when targeting another environment. Its
`aroResourceProviderObjectId` value is tenant-specific and must identify the
Azure Red Hat OpenShift resource-provider service principal in the target
tenant. The workflow runs a subscription-scope What-If and starts the deployment with
`az deployment sub create --no-wait`. While polling the named deployment, it
requests a new GitHub OIDC token and signs in to Azure every 45 minutes. If
monitoring reaches its timeout, the workflow fails but does not cancel the Azure
deployment. It uses the same runner and secrets as the standard workflow and
runs Entra configuration as a separate job after a successful ARO deployment.

For a BYO hub, set these values in `aro/main.bicepparam`:

- `hubVnetResourceId`: full resource ID of the hub VNet.
- `hubNextHopIpAddress`: private IP of its preconfigured Azure Firewall or NVA.

The deployment principal needs permission to create the hub-side peering. The
hub may be in another subscription in the same tenant. This project does not
modify a BYO firewall policy.

The Azure ARO resource creates only the control plane and initial worker pool.
Create the three-node infra pool after cluster provisioning as an OpenShift
`MachineSet`, using the `infraMachineSetVmSize` output (`Standard_D8s_v5`). GPU
and OpenSearch pools remain separate post-provisioning work.

If cluster creation fails, delete the failed ARO cluster before retrying. ARO
does not support retrying failed cluster creation in place:

```powershell
az aro delete --resource-group rg-sail-dev --name aro-sail-dev --yes
.\deploy.ps1 -ConfigFile .\config.json -DeploymentType aro
```

The deployment script detects `Failed` and `Deleting` cluster states before
starting another deployment.

The ARO API and ingress are private. Both ARO subnets use `UserDefinedRouting`
with a `0.0.0.0/0` route to the hub firewall or NVA. ARO egress lockdown proxies
mandatory service endpoints; the deployed Firewall Policy also allows optional
Red Hat registries, OpenShift update endpoints, and Microsoft Entra endpoints.
BYO hub owners must provide equivalent policy.

## Microsoft Entra authentication

Enable Entra login and provide the tenant ID. Because the cluster is private,
configuration runs separately from infrastructure deployment on a connected
host:

```json
{
  "entraId": {
    "enabled": true,
    "tenantId": "00000000-0000-0000-0000-000000000000",
    "clientId": "",
    "identityProviderName": "entraID",
    "clientSecretName": "openid-client-secret-azuread"
  }
}
```

After the cluster is reachable over peering, VPN, or ExpressRoute, run:

```powershell
./configure-entra-auth.ps1 -ConfigFile ./config.json -CreateApplicationIfMissing
```

The Entra configuration operation discovers the actual OAuth route, creates the
app registration and one-year credential, saves the generated client ID to the
configuration file, configures claims and delegated `User.Read`, and reconciles
the named OpenShift identity provider. The generated secret is piped directly
to OpenShift and then removed from the process environment. Set `clientId` to an
existing single-tenant application ID when the repository should reuse an app.

The browser callback and OpenShift console are reachable only from connected
networks. Authentication is separate from authorization: Entra users receive no
elevated OpenShift role unless an administrator creates an explicit role
binding. Entra group-name synchronization through this OIDC provider is not
supported by Red Hat.

See [DEPLOYMENT.md](DEPLOYMENT.md#microsoft-entra-authentication) for app
permissions, existing-app behavior, rotation, verification, enterprise-app
assignment, and rollback.

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

Deploy the hub from its independent subscription-scope entry point:

```powershell
az deployment sub create `
  --location swedencentral `
  --template-file ./hub/main.bicep `
  --parameters ./hub/main.bicepparam
```

Then set the protected environment values referenced by `aro/main.bicepparam` and
deploy the spoke/ARO orchestrator:

```powershell
$env:ARO_RESOURCE_PROVIDER_OBJECT_ID = az ad sp list `
  --filter "appId eq 'f1dd0a37-89c6-4e07-bcd1-ffd3d43d8875'" `
  --query '[0].id' -o tsv
$env:ARO_PULL_SECRET = Get-Content ./pull-secret.txt -Raw
az deployment sub create `
  --location swedencentral `
  --template-file ./aro/main.bicep `
  --parameters ./aro/main.bicepparam
```
