# ARO Landing-Zone Infrastructure Deployment Guide

This guide covers deploying the independent hub network, ARO spoke network, and
private Azure Red Hat OpenShift (ARO) cluster that hosts Cohere North. The
deployment uses Bicep parameter files and subscription-scope Azure CLI
deployments.

Managed application dependencies such as PostgreSQL and Redis are external to
these templates.

## Deployment layout

- `hub/main.bicep` and `hub/main.bicepparam` deploy the hub resource group, VNet,
  Azure Firewall, public IP, Firewall Policy, and egress rules.
- `aro/main.bicep` and `aro/main.bicepparam` deploy the spoke network, hub/spoke
  peering, ARO identities and RBAC, and the ARO cluster.
- `aro/aro.bicep` composes the cluster-specific identity, role-assignment, and
  cluster modules.

The hub is always a separate Azure deployment. The ARO deployment consumes the
hub VNet resource ID and firewall or network virtual appliance private IP.

## Prerequisites

1. Azure CLI with Bicep support.
2. PowerShell 7 or another shell capable of setting environment variables.
3. An Azure subscription with permission to create resource groups, networking,
   ARO resources, managed identities, and role assignments.
4. A Red Hat pull secret from the Red Hat Hybrid Cloud Console.
5. A deployment host with network access to the private ARO environment for
   post-deployment OpenShift configuration.
6. The OpenShift CLI (`oc`) for cluster administration.

Sign in and select the target subscription:

```powershell
az login
$subscriptionId = az account show --query id --output tsv
```

Register the required Azure resource providers:

```powershell
$providers = @(
  'Microsoft.Network'
  'Microsoft.RedHatOpenShift'
  'Microsoft.Compute'
  'Microsoft.Storage'
  'Microsoft.Authorization'
)

foreach ($provider in $providers) {
  az provider register --namespace $provider --wait
}
```

## Configure deployment parameters

Edit `hub/main.bicepparam` for the hub deployment:

- Azure region and hub resource group
- Hub VNet name and address prefix
- Azure Firewall subnet and resource names
- ARO spoke address prefix allowed by the Firewall Policy

Edit `aro/main.bicepparam` for the spoke and ARO deployment:

- Hub subscription, resource group, VNet name, and next-hop private IP
- Spoke VNet, subnet, and route-table settings
- ARO resource group, managed resource group, cluster name, and domain
- ARO resource-provider service-principal object ID
- Optional OpenShift version

`hubVnetResourceId` may be left empty when the hub is in the configured
subscription and resource group. The template derives the resource ID from
`hubSubscriptionId`, `hubResourceGroupName`, and `hubVnetName`.

Set the protected Red Hat pull secret without writing it to a parameter file:

```powershell
$env:ARO_PULL_SECRET = Get-Content ./pull-secret.txt -Raw
```

## Deploy the hub

Run these commands from the `infra` directory.

Preview the independent hub deployment:

```powershell
az deployment sub what-if `
  --name sail-hub-preview `
  --location swedencentral `
  --subscription $subscriptionId `
  --template-file ./hub/main.bicep `
  --parameters ./hub/main.bicepparam
```

Create the hub deployment:

```powershell
az deployment sub create `
  --name sail-hub `
  --location swedencentral `
  --subscription $subscriptionId `
  --template-file ./hub/main.bicep `
  --parameters ./hub/main.bicepparam
```

The deployment outputs the hub VNet resource ID and Azure Firewall private IP.
Ensure the corresponding values in `aro/main.bicepparam` are correct before
deploying the spoke.

## Deploy the spoke and ARO cluster

For a new environment, use the `all` stage to deploy the spoke, peering, and ARO
cluster:

```powershell
az deployment sub what-if `
  --name sail-aro-preview `
  --location swedencentral `
  --subscription $subscriptionId `
  --template-file ./aro/main.bicep `
  --parameters ./aro/main.bicepparam deploymentType=all
```

```powershell
az deployment sub create `
  --name sail-aro `
  --location swedencentral `
  --subscription $subscriptionId `
  --template-file ./aro/main.bicep `
  --parameters ./aro/main.bicepparam deploymentType=all
```

### Deploy only the spoke

The hub must already exist and the deployment identity must be able to create
peering on the hub VNet.

```powershell
az deployment sub create `
  --name sail-spoke `
  --location swedencentral `
  --subscription $subscriptionId `
  --template-file ./aro/main.bicep `
  --parameters ./aro/main.bicepparam deploymentType=spoke
```

### Deploy ARO on an existing spoke

The spoke VNet, subnets, route table, and both peerings must already exist.

```powershell
az deployment sub create `
  --name sail-aro `
  --location swedencentral `
  --subscription $subscriptionId `
  --template-file ./aro/main.bicep `
  --parameters ./aro/main.bicepparam deploymentType=aro
```

The deployment creates a private ARO cluster with user-defined routing and
standardizes the control-plane and initial worker nodes on `Standard_D8s_v5`.
Create additional infra, OpenSearch, and GPU machine pools after cluster
provisioning.

### Deploy the infrastructure MachineSet

The `aro/machinesets/infra-machineset.yaml` manifest defines three
`Standard_D8s_v5` infrastructure nodes in availability zone 1. Before applying
it, retrieve an ARO-generated worker MachineSet and replace every
`REPLACE_*` value with the matching cluster-generated value:

```powershell
oc get machinesets --namespace openshift-machine-api
oc get machineset <existing-worker-machineset> `
  --namespace openshift-machine-api `
  --output yaml
oc get infrastructure cluster `
  --output jsonpath='{.status.infrastructureName}'
```

Copy any provider-specific fields present in the generated worker MachineSet,
including image, load-balancer, identity, security, and disk settings, into the
infrastructure manifest. These values vary with the ARO and OpenShift version.

Apply and verify the MachineSet:

```powershell
oc apply --filename ./aro/machinesets/infra-machineset.yaml
oc get machinesets --namespace openshift-machine-api
oc get machines --namespace openshift-machine-api
oc get nodes --label node-role.kubernetes.io/infra
```

The manifest adds a `NoSchedule` taint. Configure the required infrastructure
workloads with the corresponding toleration before relying on these nodes.

## Use an existing hub VNet

Set the following values in `aro/main.bicepparam`:

- `hubSubscriptionId`: subscription containing the hub VNet
- `hubResourceGroupName`: resource group containing the hub VNet
- `hubVnetName`: hub VNet name
- `hubVnetResourceId`: full resource ID, or empty to derive it from the preceding
  values
- `hubNextHopIpAddress`: private IP of the existing firewall or network virtual
  appliance

The hub may be in another subscription in the same Microsoft Entra tenant. The
deployment identity must be able to create the hub-side peering. An externally
managed hub must provide equivalent firewall rules for mandatory ARO and Red Hat
endpoints.

## GitHub Actions deployment

The repository provides separate manually triggered workflows:

1. `Deploy Hub network` deploys `infra/hub/main.bicep` and its parameter file.
2. `Deploy Spoke network` deploys the `spoke` stage from
   `infra/aro/main.bicepparam`.
3. `Deploy ARO with native Azure CLI` deploys the ARO entry point from a
   self-hosted runner using managed identity.
4. `Configure ARO integration (Native)` configures Microsoft Entra
   authentication from a connected self-hosted runner.

Configure the repository or organization secrets required by the selected
workflows:

- `AZURE_CLIENT_ID`: application/client ID used by OIDC workflows
- `AZURE_MI_CLIENT_ID`: user-assigned managed identity client ID used by the ARO
  deployment workflow
- `AZURE_TENANT_ID`: Microsoft Entra tenant ID
- `AZURE_SUBSCRIPTION_ID`: target Azure subscription ID
- `ARO_PULL_SECRET`: complete Red Hat pull-secret JSON

The deployment identities require permission to register providers, create role
assignments, and manage networking at the scopes used by the templates.

## Deployment architecture

Deploy resources in this order:

1. **Hub**
   - Hub VNet and `AzureFirewallSubnet`
   - Standard Azure Firewall, public IP, and Firewall Policy
2. **Spoke**
   - ARO spoke VNet
   - Control-plane, worker, and private-endpoint subnets
   - Bidirectional peering and `0.0.0.0/0` route to the hub next hop
3. **ARO**
   - User-assigned managed identities and network role assignments
   - Private API and ingress with `UserDefinedRouting`
4. **Microsoft Entra authentication**
   - Separate operation from a host that can reach the private cluster

## Microsoft Entra authentication

Run the `Configure ARO integration (Native)` workflow after the ARO deployment
completes. The workflow reads the resource group and cluster name from
`infra/aro/main.bicepparam`, then:

- Retrieves an isolated temporary admin kubeconfig.
- Discovers the exact OAuth callback URL from the cluster.
- Creates or updates a single-tenant Microsoft Entra application.
- Adds the required ID-token claims and delegated Microsoft Graph permission.
- Creates the enterprise application when needed.
- Creates or updates the OpenShift OAuth client Secret.
- Reconciles the `entraID` provider in `OAuth/cluster`.
- Waits for the OpenShift authentication operator to become available.
- Removes the temporary kubeconfig and transient secret value.

The runner must have Azure CLI, `jq`, and `oc`, and must be able to resolve and
reach the private ARO API and ingress endpoints.

After the workflow succeeds, open the private console, select `entraID`, and
verify authentication and authorization:

```powershell
oc login --token '<token>' --server '<api-server-url>'
oc whoami
oc auth can-i --list
```

Authentication does not grant application or administrative access. Add
least-privilege project `RoleBinding` or cluster `ClusterRoleBinding` resources
separately. Keep `kubeadmin` until at least one Entra-authenticated administrator
path has been tested.

## Troubleshooting

### Authentication errors

```powershell
az login
az account show
az account list --output table
```

### Failed ARO cluster creation

Microsoft does not support retrying a failed ARO cluster creation in place.
Delete the failed cluster, wait for deletion to complete, and rerun the ARO
deployment:

```powershell
az aro delete `
  --resource-group sail-rg `
  --name aro-sail `
  --yes

az deployment sub create `
  --name sail-aro-retry `
  --location swedencentral `
  --subscription $subscriptionId `
  --template-file ./aro/main.bicep `
  --parameters ./aro/main.bicepparam deploymentType=aro
```

The hub, spoke, managed identities, and role assignments remain in place.

### Permission errors

Ensure the deployment identity has:

- Permission to create resource groups and subscription deployments
- Contributor and User Access Administrator roles, or Owner, at the required
  scopes
- Permission to query the ARO resource-provider enterprise application
- Permission to create both sides of the hub/spoke peering

### Microsoft Entra redirect URI mismatch

Rerun the `Configure ARO integration (Native)` workflow. It discovers the
callback URL from the cluster route. Confirm the URL reported by the workflow
matches the web redirect URI configured on the Entra application.

### ARO API connection timeout

Run checks from a host connected to the hub or spoke. Confirm private DNS
resolution, TCP 6443 reachability, connected peering, and the route to the hub
next hop:

```powershell
Resolve-DnsName api.<domain>.<region>.aroapp.io
Test-NetConnection api.<domain>.<region>.aroapp.io -Port 6443
az network route-table route list `
  --resource-group <network-resource-group> `
  --route-table-name aro-route-table `
  --output table
```

## Cleanup

Delete the ARO and hub resource groups only after confirming they do not contain
shared resources:

```powershell
az group delete --name sail-rg --yes --no-wait
az group delete --name sail-hub-rg --yes --no-wait
```

## Security considerations

- The ARO API and ingress are private.
- Both ARO subnets use user-defined routing through the hub firewall or network
  virtual appliance.
- The Red Hat pull secret is passed through a protected environment variable.
- Microsoft Entra client secrets are generated transiently and stored only in
  the OpenShift Secret.
- Deployment identities should use least-privilege role assignments at the
  narrowest practical scope.
- Microsoft Entra authentication and OpenShift RBAC authorization are managed
  separately.
