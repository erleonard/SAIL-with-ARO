# GitOps Configuration

This directory includes the resources required to configure and manage the ARO cluster using OpenShift GitOps (Argo CD).

The basic layout is as follows:

* argocd:  Argo CD Projects and Applications.
* cluster-config: Cluster configuration manifests (groups, cluster-roles, etc.)
* cluster-services: Cluster services (logging, monitoring, secret management, etc.)

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

Once OpenShift GitOps is installed, the GitOps bootstrap process can be initiated with a single command to deploy all cluster configuration and services. This process uses an "app of apps" pattern with hierarchical Argo CD applications:

**Single Command Deployment:**
```bash
oc apply -k 01-argocd/00-cluster-bootstrap/non-prod
```

This single command creates:
- **3 Argo CD Projects** (cluster-bootstrap, cluster-config, cluster-services)
- **Root Application** (cluster-bootstrap) that manages the entire bootstrap process

The bootstrap process then automatically creates:
- **Intermediate Applications** (cluster-config, cluster-services)
- **Individual Component Applications** (banners, external-secrets-operator, Nvidia GPU drivers, etc...)

## Per-cluster Modifications

Certain aspects of this repository require customer or cluster specific configuration.  Before deploying these manifests to your cluster, please review the following files and update accordingly:

### External Secrets

Files to modify:
  * `gitops/04-cluster-services/external-secrets/instance/overlays/*/clustersecretstore.yaml`
  * `gitops/cluster-services/external-secrets/instance/overlays/*/externalsecrets-sa.yaml`

