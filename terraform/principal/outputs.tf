output "resource_group_name" {
  description = "Main resource group."
  value       = azurerm_resource_group.main.name
}

output "aks_cluster_name" {
  description = "az aks get-credentials -g <resource_group_name> -n <this>"
  value       = module.aks.cluster_name
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer for workload identity."
  value       = module.aks.oidc_issuer_url
}

output "key_vault_csi_identity_client_id" {
  description = "userAssignedIdentityID for the SecretProviderClass (SL-58)."
  value       = module.aks.key_vault_csi_identity_client_id
}

output "postgres_fqdn" {
  description = "Private FQDN of PostgreSQL."
  value       = module.datos.server_fqdn
}

output "key_vault_name" {
  description = "Key Vault with the app secrets (database-url-<env>, jwt-secret-<env>, jwt-refresh-secret-<env>, api-sports-key)."
  value       = module.seguridad.key_vault_name
}

output "key_vault_uri" {
  description = "Key Vault URI (keyVaultName / vault URL for the SecretProviderClass, SL-58)."
  value       = module.seguridad.key_vault_uri
}

output "tenant_id" {
  description = "Entra tenant id for the SecretProviderClass (SL-58)."
  value       = module.seguridad.tenant_id
}
