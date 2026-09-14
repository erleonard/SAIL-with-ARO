# OpenShift Logging

This directory contains the GitOps configuration for deploying the OpenShift Logging Operator and ClusterLogForwarder.

## Overview

The OpenShift Logging Operator provides centralized logging capabilities for the SAIL with ARO deployment, forwarding logs to Azure Monitor for compliance with Canadian data sovereignty requirements.

## Structure

The structure follows the established gitops pattern:

```
openshift-logging/
├── operator/base                  # Namespace, OperatorGroup, Subscription
├── overlays/<environment>/        # Bundle entrypoint + appset-config.yaml
└── instance/                      # ClusterLogForwarder configuration
    ├── base/
    └── overlays/<environment>/
```

## ApplicationSet Integration

This service is automatically discovered by the `cluster-services` ApplicationSet located at:
`gitops/01-argocd/02-applicationsets/base/cluster-services-appset.yaml`

The ApplicationSet will create ArgoCD Applications for:
- `gitops/03-cluster-services/openshift-logging/operator/overlays/non-prod`
- `gitops/03-cluster-services/openshift-logging/operator/overlays/prod`
- `gitops/03-cluster-services/openshift-logging/instance/overlays/non-prod`
- `gitops/03-cluster-services/openshift-logging/instance/overlays/prod`

## Operator Configuration

The OpenShift Logging Operator is configured via the subscription in `operator/base/subscription.yaml`:
- **Operator**: cluster-logging
- **Source**: redhat-operators
- **Channel**: stable
- **Namespace**: openshift-logging

## ClusterLogForwarder Configuration

The ClusterLogForwarder is configured in `instance/base/clusterlogforwarder.yaml` with placeholder values for Azure Monitor integration:

### Placeholder Values
- `REPLACE_WITH_CUSTOMER_ID` - Azure Log Analytics workspace customer ID
- `REPLACE_WITH_SHARED_KEY` - Azure Log Analytics workspace shared key
- `REPLACE_WITH_REGION` - Azure region for data sovereignty

### Log Collection Configuration
The ClusterLogForwarder collects logs from:
- Application logs
- Infrastructure logs
- Audit logs

All logs are forwarded to Azure Monitor via the configured output.

## External Secrets Integration

The placeholder values in the ClusterLogForwarder should be replaced with values from the External Secrets Operator:
- Secrets should be defined in `gitops/03-cluster-services/external-secrets/instance/`
- Use the External Secrets pattern established in the project
- Ensure Azure credentials are properly secured

## Deployment

**Important**: The ClusterLogForwarder contains placeholder values and should NOT be applied to the cluster until:
1. The OpenShift Logging Operator is successfully deployed
2. Real Azure Monitor credentials are configured via External Secrets
3. Placeholder values are replaced with actual values

### Deployment Steps
1. Enable the logging service overlay for your environment in ArgoCD
2. Verify OpenShift Logging Operator deployment
3. Configure External Secrets with Azure Monitor credentials
4. Update ClusterLogForwarder with real values or use External Secrets references
5. Apply the ClusterLogForwarder configuration

## Compliance Notes

- Ensure all Azure resources are deployed in Canadian regions for data sovereignty
- Configure appropriate log retention policies
- Follow security best practices for Azure credentials management
- Test with production workloads before full deployment