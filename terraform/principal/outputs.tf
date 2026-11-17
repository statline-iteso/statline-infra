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

output "ingress_public_ip" {
  description = "Static public IP of the ingress-nginx load balancer (point DNS here, or use it when no domain is set)."
  value       = azurerm_public_ip.ingress.ip_address
}

output "dns_name_servers" {
  description = "Name servers of the DNS zone to delegate at the registrar. Null when dominio is not set."
  value       = one(module.dns[*].name_servers)
}

output "grafana_admin_password" {
  description = "Grafana admin password (user admin). Read with: terraform output -raw grafana_admin_password. Not written to any file."
  value       = module.plataforma.grafana_admin_password
  sensitive   = true
}
