output "resource_group_name" {
  description = "Resource group of the state storage account."
  value       = azurerm_resource_group.tfstate.name
}

output "storage_account_name" {
  description = "Storage account that holds remote state (written into principal/backend.hcl)."
  value       = azurerm_storage_account.tfstate.name
}

output "container_name" {
  description = "Blob container for state files."
  value       = azurerm_storage_container.tfstate.name
}
