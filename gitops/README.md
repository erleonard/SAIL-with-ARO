# GitOps Configuration

This directory includes the resources required to configure and manage the ARO cluster using OpenShift GitOps (Argo CD).

The basic layout is as follows:

* argocd:  Argo CD Projects and Applications.
* cluster-config: Cluster configuration manifests (groups, cluster-roles, etc.)
* cluster-services: Cluster services (logging, monitoring, secret management, etc.)

## Getting Started

The OpenShift GitOps Operator needs to be installed first.  This might end up becoming part of the Bicep template, but for now we can deploy it with a single CLI command, assuming you are logged in using the OpenShift CLI (`oc`) as a `cluster-admin`.

