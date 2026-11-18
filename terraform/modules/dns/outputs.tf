output "name_servers" {
  description = "Name servers to delegate the domain to at the registrar."
  value       = azurerm_dns_zone.main.name_servers
}
