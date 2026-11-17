output "server_fqdn" {
  description = "Private FQDN of the server."
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "database_names" {
  description = "Application databases on the server (statline_<env>)."
  value       = [for db in azurerm_postgresql_flexible_server_database.app : db.name]
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

output "database_urls" {
  description = "DATABASE_URL per environment (key = env, e.g. staging, prod), with the admin login and sslmode=require. Stored in Key Vault by module seguridad."
  value = {
    for name, db in azurerm_postgresql_flexible_server_database.app :
    trimprefix(name, "statline_") => format(
      "postgresql://%s:%s@%s:5432/%s?sslmode=require",
      urlencode(azurerm_postgresql_flexible_server.main.administrator_login),
      urlencode(random_password.admin.result),
      azurerm_postgresql_flexible_server.main.fqdn,
      db.name,
    )
  }
  sensitive = true
}

output "server_id" {
  description = "PostgreSQL Flexible Server id (diagnostic settings in module observabilidad)."
  value       = azurerm_postgresql_flexible_server.main.id
}
