# Everything StatLine runs on, in one stack (proposal §4.1). One AKS cluster hosts the
# statline-staging and statline-prod namespaces; one PostgreSQL server hosts their databases.

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
  subscription_id = var.subscription_id
}

resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name}"
  location = var.location
  tags     = local.tags
}

module "red" {
  source              = "../modules/red"
  name                = local.name
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  address_space       = "10.0.0.0/16"
  tags                = local.tags
}

module "aks" {
  source              = "../modules/aks"
  name                = local.name
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  subnet_id           = module.red.aks_subnet_id
  kubernetes_version  = var.kubernetes_version
  node_vm_size        = var.node_vm_size
  node_min_count      = 2
  node_max_count      = 4
  tags                = local.tags
}

module "datos" {
  source              = "../modules/datos"
  name                = local.name
  suffix              = random_string.suffix.result
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  subnet_id           = module.red.postgres_subnet_id
  private_dns_zone_id = module.red.postgres_private_dns_zone_id
  tags                = local.tags

  depends_on = [module.red]
}

module "seguridad" {
  source                 = "../modules/seguridad"
  name                   = local.name
  suffix                 = random_string.suffix.result
  resource_group_name    = azurerm_resource_group.main.name
  location               = var.location
  csi_identity_object_id = module.aks.key_vault_csi_identity_object_id
  database_urls          = module.datos.database_urls
  tags                   = local.tags
}

# ── Pending (second half, see docs/BACKLOG.md) ──────────────────────────────
#
# TODO(SL-10) module "observabilidad": log_analytics_workspace + diagnostic_settings for AKS,
#   PostgreSQL and Key Vault; then wire oms_agent in module aks.
#
# TODO(SL-12) module "dns": dns_zone + A record to the ingress public_ip.
#   module "plataforma": helm_release ingress-nginx, cert-manager, argo-cd,
#   kube-prometheus-stack and redis (Bitnami), using module.aks.kube_config.
