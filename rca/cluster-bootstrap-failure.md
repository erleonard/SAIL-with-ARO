# Cluster Bootstrap Failure - Root Cause Analysis

## Executive Summary

The cluster bootstrap process fails after executing `oc apply -k argocd/cluster-bootstrap/non-prod`, with only the "cluster-bootstrap" Application being created. The failure occurs during Application synchronization with a kustomize build error related to strategic merge patches.

## Error Details

**Original Error:**
```
Failed to load target state: failed to generate manifest for source 1 of 1: rpc error: code = Unknown desc = `kustomize build <path to cached source>/gitops/argocd/managed-apps/overlays/non-prod` failed exit status 1: Error: no resource matches strategic merge patch "Application.v1alpha1.argoproj.io/cluster-config.[noNs]": no matches for Id Application.v1alpha1.argoproj.io/cluster-config.[noNs]; failed to find unique target for patch Application.v1alpha1.argoproj.io/cluster-config.[noNs]
```

## Root Cause Analysis

### 1. Configuration Structure Issue

**Location:** `/projects/sail-with-aro/gitops/argocd/managed-apps/overlays/non-prod/kustomization.yaml:7-24`

The overlay kustomization file attempts to use strategic merge patches to modify Application resources, but kustomize cannot find matching target resources:

```yaml
patches:
- patch: |-
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: cluster-config
      namespace: openshift-gitops
    spec:
      source:
        path: gitops/argocd/applications/cluster-config/00-non-prod
- patch: |-
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: cluster-services
      namespace: openshift-gitops
    spec:
      source:
        path: gitops/argocd/applications/cluster-services/00-non-prod
```

### 2. Missing Application Resources

**Problem:** The patches reference non-existent directories:
- `gitops/argocd/applications/cluster-config/00-non-prod`
- `gitops/argocd/applications/cluster-services/00-non-prod`

**Verification:** The `/projects/sail-with-aro/gitops/argocd/applications/` directory does not exist, confirming these paths are invalid.

### 3. Base Application Configuration Issues

**Location:** `/projects/sail-with-aro/gitops/argocd/managed-apps/base/cluster-config-application.yaml:10`

The base Application resources contain placeholder paths:
```yaml
source:
  path: set/in/overlay
```

This indicates the paths were never properly configured for the actual application locations.

### 4. Resource Matching Problems

**Issue:** Strategic merge patches require exact matches with existing resources including:
- `apiVersion`
- `kind`
- `metadata.name`
- `metadata.namespace`

The patches may not be properly matching the base Application resources due to namespace or naming inconsistencies.

## Impact Assessment

**Severity:** High - Complete cluster bootstrap failure
**Scope:** No managed applications are deployed beyond the bootstrap Application
**Business Impact:** GitOps-based cluster management cannot proceed

## File Structure Analysis

### Current Structure
```
gitops/
├── argocd/
│   ├── cluster-bootstrap/
│   │   └── non-prod/
│   │       ├── bootstrap-application.yaml
│   │       └── kustomization.yaml
│   ├── managed-apps/
│   │   ├── base/
│   │   │   ├── cluster-config-application.yaml
│   │   │   ├── cluster-services-application.yaml
│   │   │   └── kustomization.yaml
│   │   └── overlays/
│   │       └── non-prod/
│   │           └── kustomization.yaml
│   └── projects/
│       ├── cluster-bootstrap-project.yaml
│       └── kustomization.yaml
```

### Missing Structure
The following directories referenced in the patches do not exist:
```
argocd/applications/cluster-config/00-non-prod/
argocd/applications/cluster-services/00-non-prod/
```

## Recommended Solutions

### Option 1: Create Missing Application Structure (Recommended)

1. **Create missing application directories:**
   ```bash
   mkdir -p argocd/applications/cluster-config/00-non-prod
   mkdir -p argocd/applications/cluster-services/00-non-prod
   ```

2. **Create Application resources in the new directories** with proper configuration for cluster-config and cluster-services

3. **Update base Applications** to point to correct paths instead of `set/in/overlay`

### Option 2: Simplify Kustomization Structure

1. **Remove strategic merge patches** from the overlay kustomization.yaml
2. **Include Application resources directly** in the overlay
3. **Modify base Applications** to use environment-specific paths directly

### Option 3: Fix Patch Targeting

1. **Verify namespace consistency** between base Applications and patches
2. **Ensure resource names match exactly** in patches and base resources
3. **Add missing metadata.namespace** to base Applications if needed

## Next Steps

1. **Immediate:** Choose one of the three solution options
2. **Implementation:** Execute the selected fix
3. **Verification:** Test with `kustomize build` to ensure no build errors
4. **Validation:** Re-run `oc apply -k argocd/cluster-bootstrap/non-prod`

## Technical Notes

- The bootstrap Application correctly points to `/gitops/argocd/managed-apps/overlays/non-prod`
- The issue occurs during kustomize build phase, not during Argo CD processing
- Project resources are correctly configured in `/projects/sail-with-aro/gitops/argocd/projects/`

---
**Analysis Date:** 2026-09-01
**Directory Analyzed:** /projects/sail-with-aro/gitops