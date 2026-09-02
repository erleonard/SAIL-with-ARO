# GitOps Configuration

This directory includes the resources required to configure and manage the ARO cluster using OpenShift GitOps (Argo CD).

The basic layout is as follows:

* `00-init`: The OpenShift GitOps (Argo CD) operator installation.
* `01-argocd`: Argo CD AppProjects, the environment bootstrap, and the ApplicationSets that generate component Applications.
* `02-cluster-config`: Cluster configuration manifests (banners, cluster-roles, drivers, etc.)
* `03-cluster-services`: Cluster services (logging, monitoring, secret management, etc.)

## Getting Started

The OpenShift GitOps Operator needs to be installed first.  This might end up becoming part of the Bicep template, but for now we can deploy it with a single CLI command, assuming you are logged in using the OpenShift CLI (`oc`) as a `cluster-admin`.

```
cd gitops
oc apply -k 00-init/openshift-gitops
```

This will take a few moments to install the initial instance of OpenShift GitOps (Argo CD).  You'll know it's ready when you see the following pods in your cluster:

```
oc get pods -n openshift-gitops
NAME                                                         READY   STATUS    RESTARTS   AGE
cluster-b9cddf87-md9ng                                       1/1     Running   0          3m58s
gitops-plugin-644959567b-llx9c                               1/1     Running   0          3m58s
openshift-gitops-application-controller-0                    1/1     Running   0          3m56s
openshift-gitops-applicationset-controller-d5fd4676d-6fw62   1/1     Running   0          3m56s
openshift-gitops-dex-server-7d5db9fbd-9ngd4                  1/1     Running   0          3m56s
openshift-gitops-redis-7b984f5f5d-fdz2p                      1/1     Running   0          3m57s
openshift-gitops-repo-server-7fb8b7f78-vxsz2                 1/1     Running   0          3m57s
openshift-gitops-server-7bf4f84fd8-pp55x                     1/1     Running   0          3m57s
```

### GitOps Bootstrap Process

Once OpenShift GitOps is installed, a single command bootstraps all cluster
configuration and services for an environment:

**Single Command Deployment:**
```bash
oc apply -k 01-argocd/00-cluster-bootstrap/non-prod
```

This single command creates:
- **3 Argo CD AppProjects** (cluster-bootstrap, cluster-config, cluster-services)
- **Root Application** (cluster-bootstrap) that manages the rest of the bootstrap

From there, reconciliation is direct:

1. The root Application creates the `cluster-config` and `cluster-services`
   ApplicationSets.
2. Each ApplicationSet scans the repository for `appset-config.yaml`
   descriptors belonging to the selected environment.
3. Each descriptor generates one Application whose source path is the directory
   containing that descriptor.

```text
bootstrap/<environment>
→ applicationsets/overlays/<environment>
→ appset-config.yaml
→ containing Kustomize payload overlay
```

A component is deployed to an environment by adding a descriptor to its
environment overlay, and undeployed by removing it. Creating a directory alone
deploys nothing.

See [the Argo CD architecture README](01-argocd/README.md) for the descriptor
contract, the service-bundle model, and instructions for adding a component.

## Per-cluster Modifications

Certain aspects of this repository require customer or cluster specific configuration.  Before deploying these manifests to your cluster, please review the following files and update accordingly:

### External Secrets

Files to modify:
  * `gitops/03-cluster-services/external-secrets/instance/base/clustersecretstore.yaml` (the vault URL is patched in `instance/overlays/*/kustomization.yaml`)
  * `gitops/03-cluster-services/external-secrets/instance/overlays/*/externalsecrets-sa.yaml`

The External Secrets instance is not deployed yet. Once the values above are
set, add `../../instance/overlays/<environment>` to the bundle Kustomization at
`gitops/03-cluster-services/external-secrets/overlays/<environment>/kustomization.yaml`.

