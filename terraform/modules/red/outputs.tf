output "vnet_id" {
  description = "VNet id."
  value       = azurerm_virtual_network.main.id
}

output "aks_subnet_id" {
  description = "Subnet for AKS nodes and pods."
  value       = azurerm_subnet.aks.id
}

output "postgres_subnet_id" {
  description = "Subnet delegated to PostgreSQL Flexible Server."
  value       = azurerm_subnet.postgres.id
}

output "postgres_private_dns_zone_id" {
  description = "Private DNS zone for the database."
  value       = azurerm_private_dns_zone.postgres.id
}
