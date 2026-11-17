output "server_fqdn" {
  description = "Private FQDN of the server."
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "database_name" {
  description = "Application database."
  value       = azurerm_postgresql_flexible_server_database.statline.name
}

output "admin_login" {
  description = "Administrator login."
  value       = azurerm_postgresql_flexible_server.main.administrator_login
}

output "admin_password" {
  description = "Administrator password. Goes to Key Vault (module seguridad), never to a file."
  value       = random_password.admin.result
  sensitive   = true
}

output "database_url" {
  description = "DATABASE_URL for the api, ingesta and predicciones (stored in Key Vault)."
  value = format(
    "postgresql://%s:%s@%s:5432/%s?sslmode=require",
    azurerm_postgresql_flexible_server.main.administrator_login,
    random_password.admin.result,
    azurerm_postgresql_flexible_server.main.fqdn,
    azurerm_postgresql_flexible_server_database.statline.name,
  )
  sensitive = true
}

output "server_id" {
  description = "PostgreSQL Flexible Server id (diagnostic settings in module observabilidad)."
  value       = azurerm_postgresql_flexible_server.main.id
}
