# Multi-Cluster GitOps Architecture with Argo CD

This directory contains the Argo CD projects and applications that implement a comprehensive multi-cluster GitOps architecture for the SAIL-with-ARO platform using a hierarchical "app of apps" pattern with environment-specific overlays.

## Architecture Overview

The GitOps implementation uses a sophisticated multi-cluster, multi-environment architecture:

### 1. **Bootstrap Layer** (`00-cluster-bootstrap/`)
- **Environment-specific bootstrap applications** for `prod` and `non-prod` clusters
- Each bootstrap application deploys the managed apps layer for its respective environment
- Implements the initial GitOps bootstrap process with automated sync policies

### 2. **Project Layer** (`01-projects/`)
Defines three core Argo CD projects for resource isolation:
- `cluster-bootstrap-project`: Root project for bootstrap process (full cluster access)
- `cluster-config-project`: Manages cluster configuration applications
- `cluster-services-project`: Manages cluster service applications

### 3. **Managed Applications Layer** (`02-managed-apps/`)
- **Base applications**: `cluster-config` and `cluster-services` applications
- **Environment overlays**: Separate `prod` and `non-prod` configurations
- Uses Kustomize patches to customize source paths per environment

### 4. **Cluster Configuration Layer** (`03-cluster-config/`)
Environment-specific cluster configuration management:
- `00-prod/`: Production cluster configurations
- `00-non-prod/`: Non-production cluster configurations
- `banners/`: Cluster banner applications with environment-specific overlays

### 5. **Cluster Services Layer** (`04-cluster-services/`)
Multi-tenant service deployments with environment separation:
- `00-prod/`: Production service configurations
- `00-non-prod/`: Non-production service configurations
- `external-secrets/`: Comprehensive External Secrets Operator setup with:
  - `operator/`: Operator deployment (base + environment overlays)
  - `instance/`: Secret instance management (base + environment overlays)

## Key Features

### Multi-Cluster Support
- Separate bootstrap and configuration paths for production and non-production clusters
- Environment-specific synchronization policies and resource targets
- Isolated project namespaces for security and governance

### Hierarchical Application Structure
```
Bootstrap App → Managed Apps → Configuration/Services Apps → Individual Components
```

### Kustomize-Based Configuration
- **Base configurations** define common application specs
- **Environment overlays** customize deployments per cluster environment
- **Patches** modify specific application parameters without duplication

### Security & Governance
- Project-based resource whitelisting and access control
- Automated sync policies with pruning and self-healing
- Namespace-scoped destination control per project

## Directory Structure

```
01-argocd/
├── 00-cluster-bootstrap/          # Environment-specific bootstrap apps
│   ├── prod/
│   │   ├── bootstrap-application.yaml
│   │   └── kustomization.yaml
│   └── non-prod/
│       ├── bootstrap-application.yaml
│       └── kustomization.yaml
├── 01-projects/                    # Argo CD project definitions
│   ├── cluster-bootstrap-project.yaml
│   ├── cluster-config-project.yaml
│   ├── cluster-services-project.yaml
│   └── kustomization.yaml
├── 02-managed-apps/                # Intermediate management applications
│   ├── base/                       # Base cluster-config/services apps
│   │   ├── cluster-config-application.yaml
│   │   ├── cluster-services-application.yaml
│   │   └── kustomization.yaml
│   └── overlays/                   # Environment-specific configurations
│       ├── prod/
│       │   └── kustomization.yaml
│       └── non-prod/
│           └── kustomization.yaml
├── 03-cluster-config/              # Cluster configuration applications
│   ├── 00-prod/                    # Production configurations
│   ├── 00-non-prod/                # Non-production configurations
│   └── banners/                    # Banner applications
│       ├── base/
│       └── overlays/
│           ├── prod/
│           └── non-prod/
└── 04-cluster-services/            # Cluster service applications
    ├── 00-prod/                    # Production services
    ├── 00-non-prod/                # Non-production services
    └── external-secrets/           # External Secrets Operator
        ├── operator/               # Operator deployment
        │   ├── base/
        │   └── overlays/
        │       ├── prod/
        │       └── non-prod/
        └── instance/               # Secret instances
            ├── base/
            └── overlays/
                ├── prod/
                └── non-prod/
```

## Deployment Flow

1. **Initial Bootstrap**: Bootstrap application deploys managed apps for the environment
2. **Managed Apps**: Deploy cluster-config and cluster-services applications
3. **Configuration Layer**: Environment-specific configurations are applied
4. **Service Layer**: Multi-tenant services with operator and instance separation
5. **Component Applications**: Individual components (banners, external-secrets) with environment customization
