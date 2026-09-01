# GitOps Bootstrap Process with Argo CD

This directory contains the Argo CD projects and applications that implement the GitOps bootstrap process for the SAIL-with-ARO cluster using the "app of apps" pattern.

## Architecture

The GitOps bootstrap uses a hierarchical "app of apps" pattern:

1. **Root Application** (`cluster-bootstrap`): Creates the initial projects and manages the bootstrap process
2. **Intermediate Applications**: 
   - `cluster-config`: Manages all configuration applications
   - `cluster-services`: Manages all service applications
3. **Component Applications**: Individual applications for each component (banners, external-secrets, etc.)

## Directory Structure

```
gitops/
├── argocd/
│   ├── kustomization.yaml              # Main entry point
│   ├── projects/                       # Argo CD Projects
│   │   ├── kustomization.yaml
│   │   ├── cluster-bootstrap-project.yaml
│   │   ├── cluster-config-project.yaml
│   │   └── cluster-services-project.yaml
│   ├── applications/                   # Root and component applications
│   │   ├── kustomization.yaml
│   │   ├── cluster-bootstrap-application.yaml
│   │   └── cluster-config/
│   │       └── banners-application.yaml
│   ├── managed-apps/                   # Managed by bootstrap app
│   │   ├── kustomization.yaml
│   │   ├── cluster-config-application.yaml
│   │   └── cluster-services-application.yaml
│   └── cluster-services/
│       ├── external-secrets-operator-application.yaml
│       └── external-secrets-instance-application.yaml
└── deploy/                             # Deployment scripts
    ├── deploy-non-prod.sh
    └── deploy-prod.sh
```

## Argo CD Projects

### 1. cluster-bootstrap Project
- **Purpose**: Root project for the bootstrap process
- **Contains**: Only the `cluster-bootstrap` application
- **Scope**: Full cluster access for bootstrapping other components

### 2. cluster-config Project
- **Purpose**: Configuration management components
- **Contains**: All configuration-related applications (e.g., banners)
- **Scope**: Configuration namespaces only

### 3. cluster-services Project
- **Purpose**: Service components
- **Contains**: All service-related applications (e.g., external-secrets)
- **Scope**: Service namespaces only

## Deployment

### Prerequisites
- OpenShift GitOps (Argo CD) must already be installed and running
- Must be logged in as a user with cluster-admin privileges

### Single Command Deployment

For any cluster (non-prod or prod), use a single command:

```bash
# Deploy to the current cluster
oc apply -k gitops/argocd
```

### Environment-Specific Deployment

For additional safety checks and environment confirmation:

```bash
# Deploy to non-production cluster
./gitops/deploy/deploy-non-prod.sh

# Deploy to production cluster (with additional safety checks)
./gitops/deploy/deploy-prod.sh
```

## How It Works

### 1. Initial Deployment
The `oc apply -k gitops/argocd` command creates:
- **3 Argo CD Projects** (cluster-bootstrap, cluster-config, cluster-services)
- **1 Root Application** (cluster-bootstrap)

### 2. App-of-Apps Cascade
The `cluster-bootstrap` application then creates:
- **2 Intermediate Applications** (cluster-config, cluster-services)

### 3. Component Deployment
Each intermediate application manages individual components:
- `cluster-config` → `banners` application
- `cluster-services` → `external-secrets-operator`, `external-secrets-instance` applications

## Application Hierarchy

```
cluster-bootstrap (project: cluster-bootstrap)
├── cluster-config (project: cluster-bootstrap)
│   └── banners (project: cluster-config)
└── cluster-services (project: cluster-bootstrap)
    ├── external-secrets-operator (project: cluster-services)
    └── external-secrets-instance (project: cluster-services)
```

## Monitoring Deployment

### Check Application Status
```bash
# List all applications
argocd app list

# Get specific application status
argocd app get cluster-bootstrap
argocd app get cluster-config
argocd app get cluster-services

# Watch application sync status
argocd app sync cluster-bootstrap --dry-run
argocd app sync --all
```

### Check Application Health
```bash
# Check application health in OpenShift
oc get applications -n openshift-gitops -o wide

# Check Argo CD server logs
oc logs -n openshift-gitops -l app=openshift-gitops-server
```

## Component Details

### cluster-bootstrap
- **Project**: cluster-bootstrap
- **Source**: `gitops/argocd/managed-apps/`
- **Purpose**: Root application that orchestrates the entire bootstrap process

### cluster-config
- **Project**: cluster-bootstrap
- **Source**: `gitops/argocd/applications/cluster-config/`
- **Purpose**: Manages all cluster configuration applications

### cluster-services
- **Project**: cluster-bootstrap
- **Source**: `gitops/argocd/applications/cluster-services/`
- **Purpose**: Manages all cluster service applications

### banners
- **Project**: cluster-config
- **Source**: `gitops/cluster-config/banners/`
- **Purpose**: Cluster configuration banner management

### external-secrets-operator
- **Project**: cluster-services
- **Source**: `gitops/cluster-services/external-secrets/operator/`
- **Purpose**: External secrets operator installation

### external-secrets-instance
- **Project**: cluster-services
- **Source**: `gitops/cluster-services/external-secrets/instance/`
- **Purpose**: External secrets instance configuration

## Sync Policy

All applications are configured with automated sync policy:
- `prune: true` - Automatically remove resources that are no longer defined
- `selfHeal: true` - Automatically sync when drift is detected

## Repository Configuration

All applications reference the main repository:
- **repoURL**: `https://github.com/erleonard/SAIL-with-ARO.git`
- **targetRevision**: `main`
- Source paths are relative to the repository root

## Multi-Cluster Support

### Non-Production Clusters
- Use `./gitops/deploy/deploy-non-prod.sh` for additional safety checks
- Standard deployment without extra confirmations
- Ideal for development, staging, and testing environments

### Production Clusters
- Use `./gitops/deploy/deploy-prod.sh` for production safety checks
- Includes additional confirmation prompts
- Suitable for production environments

### Custom Cluster Configuration

To customize deployment for specific clusters:
1. Create cluster-specific overlays in `gitops/argocd/cluster-overlays/`
2. Reference additional configurations in the overlay kustomization
3. Deploy using `oc apply -k gitops/argocd/cluster-overlays/<cluster-name>/`

## Troubleshooting

### Application Won't Sync
```bash
# Check application logs
argocd app logs cluster-bootstrap

# Check Argo CD server status
oc get pods -n openshift-gitops

# Check repository connectivity
argocd repo list
```

### Projects Not Created
```bash
# Check if projects exist
oc get appprojects -n openshift-gitops

# Check for project errors
oc describe appproject cluster-bootstrap -n openshift-gitops
```

### Permission Issues
- Ensure you're logged in as a cluster-admin
- Check that the `openshift-gitops` namespace exists
- Verify Argo CD has proper RBAC permissions

## Adding New Components

### For Configuration Components:
1. Create directory under `gitops/cluster-config/`
2. Add Argo CD application under `gitops/argocd/applications/cluster-config/`
3. Add application reference to `gitops/argocd/applications/cluster-config/kustomization.yaml`
4. Ensure application belongs to `cluster-config` project

### For Service Components:
1. Create directory under `gitops/cluster-services/`
2. Add Argo CD application under `gitops/argocd/cluster-services/`
3. Add application reference to the appropriate kustomization file
4. Ensure application belongs to `cluster-services` project

## Success Criteria

- ✅ Single `oc apply -k gitops/argocd` command deploys everything
- ✅ All three Argo CD Projects are created
- ✅ Root `cluster-bootstrap` application is deployed and healthy
- ✅ Intermediate applications (cluster-config, cluster-services) are created
- ✅ Individual component applications are deployed correctly
- ✅ App-of-apps pattern works without manual intervention
- ✅ Project isolation ensures proper RBAC and namespace scoping