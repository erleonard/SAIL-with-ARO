# Red Hat External Secrets Operator

The External Secrets operator requires customer/envitonment specific configuration.

Please review and update the following files before applying them:
* `instance/externalsecrets-sa.yaml`
* `instance/clustersecretstore.yaml`

The configuration in this repository relies on [Azure Workload Identity](https://learn.microsoft.com/en-us/entra/workload-id/workload-identities-overview).  Work with your Azure cloud team to configure workload identity.  An example of the `az` cli commands to configure this is bellow.

```
export OIDC_ISSUER=$(az aro show \
  --name <aro-cluster-name> \
  --resource-group <aro-resource-group> \
  --query "clusterProfile.oidcIssuer" -o tsv)

az identity create \
  --name <managed-identity-name> \
  --resource-group <resource-group> \
  --location <location>

# Fetch Principal ID of the Managed Identity
export IDENTITY_PRINCIPAL_ID=$(az identity show \
  --name <managed-identity-name> \
  --resource-group <resource-group> \
  --query principalId -o tsv)

# Fetch Key Vault Scope ID
export KEYVAULT_ID=$(az keyvault show \
  --name <keyvault-name> \
  --resource-group <resource-group> \
  --query id -o tsv)

# Assign Key Vault Secrets User Role
az role assignment create \
  --assignee-object-id $IDENTITY_PRINCIPAL_ID \
  --assignee-principal-type ServicePrincipal \
  --role "Key Vault Secrets User" \
  --scope $KEYVAULT_ID

az identity federated-credential create \
  --name <federated-cred-name> \
  --identity-name <managed-identity-name> \
  --resource-group <resource-group> \
  --issuer "$OIDC_ISSUER" \
  --subject "system:serviceaccount:<eso-namespace>:<eso-service-account-name>" \
  --audience "api://AzureADTokenExchange"

az identity show \
  --name <managed-identity-name> \
  --resource-group <resource-group> \
  --query clientId -o tsv
```
