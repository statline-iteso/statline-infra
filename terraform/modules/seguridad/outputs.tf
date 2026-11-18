output "key_vault_name" {
  description = "Key Vault name (az keyvault secret list --vault-name <this>)."
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "Key Vault URI (keyvaultName/vaultUri in the SecretProviderClass)."
  value       = azurerm_key_vault.main.vault_uri
}

output "tenant_id" {
  description = "Entra tenant id (tenantId in the SecretProviderClass)."
  value       = data.azurerm_client_config.current.tenant_id
}

output "key_vault_id" {
  description = "Key Vault resource id (diagnostic settings in module observabilidad)."
  value       = azurerm_key_vault.main.id
}
