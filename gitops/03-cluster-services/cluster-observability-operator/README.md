# Cluster Observability Operator

This directory contains the GitOps configuration for deploying the OpenShift Cluster Observability Operator.

The Cluster Observability Operator (COO) provides the tools to deploy UI Plugins (Logging, Traces, Metrics Dashboards, etc)
as well as Prometheus instances.

## Structure

The structure follows the established gitops pattern:

```
cluster-observability-operator/
├── operator/base                  # Namespace, OperatorGroup, Subscription
└── overlays/<environment>/        # Bundle entrypoint + appset-config.yaml
```

## ApplicationSet Integration

This service is automatically discovered by the `cluster-services` ApplicationSet located at:
`gitops/01-argocd/02-applicationsets/base/cluster-services-appset.yaml`

The ApplicationSet will create ArgoCD Applications for:
- `gitops/03-cluster-services/cluster-observability-operator/overlays/non-prod`
- `gitops/03-cluster-services/cluster-observability-operator/overlays/prod`

## Subscription Configuration

The subscription details in `operator/base/subscription.yaml` need to be completed with:
- Correct channel for the Cluster Observability Operator
- Any additional configuration specific to the operator

## Deployment

Once the subscription is properly configured, the operator will be deployed automatically by ArgoCD when the service overlay is enabled for a cluster environment.