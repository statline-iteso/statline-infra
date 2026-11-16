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

output "database_url" {
  description = "DATABASE_URL; goes to Key Vault in module seguridad (SL-09)."
  value       = module.datos.database_url
  sensitive   = true
}
