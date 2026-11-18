# dns: public zone for var.dominio and the A records that point at the ingress. Only created when
# the domain is decided (principal: count = var.dominio == null ? 0 : 1).
# Records: apex (prod, follows main) and staging (follows develop); both are served by the same
# ingress-nginx and told apart by the Ingress host in gitops/.

resource "azurerm_dns_zone" "main" {
  name                = var.dominio
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_dns_a_record" "apex" {
  name                = "@"
  zone_name           = azurerm_dns_zone.main.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [var.ingress_public_ip]
  tags                = var.tags
}

resource "azurerm_dns_a_record" "staging" {
  name                = "staging"
  zone_name           = azurerm_dns_zone.main.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [var.ingress_public_ip]
  tags                = var.tags
}
