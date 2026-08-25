# GitOps Configuration

This directory includes the resources required to configure and manage the ARO cluster using OpenShift GitOps (Argo CD).

The basic layout is as follows:

* argocd:  Argo CD Projects and Applications.
* cluster-config: Cluster configuration manifests (groups, cluster-roles, etc.)
* cluster-services: Cluster services (logging, monitoring, secret management, etc.)

## Getting Started

The OpenShift GitOps Operator needs to be installed first.  This might end up becoming part of the Bicep template, but for now we can deploy it with a single CLI command, assuming you are logged in using the OpenShift CLI (`oc`) as a `cluster-admin`.

```
oc apply -k bootstrap/openshift-gitops
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

