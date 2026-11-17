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

# Kubernetes and Helm providers read the admin kubeconfig of the cluster created in module aks.
# On a cluster that does not exist yet, these values are unknown at plan time: apply module aks
# first (`make apply-aks`), see README "First apply".
provider "kubernetes" {
  host                   = module.aks.kube_config.host
  client_certificate     = base64decode(module.aks.kube_config.client_certificate)
  client_key             = base64decode(module.aks.kube_config.client_key)
  cluster_ca_certificate = base64decode(module.aks.kube_config.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = module.aks.kube_config.host
    client_certificate     = base64decode(module.aks.kube_config.client_certificate)
    client_key             = base64decode(module.aks.kube_config.client_key)
    cluster_ca_certificate = base64decode(module.aks.kube_config.cluster_ca_certificate)
  }
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

# Static public IP for the ingress-nginx load balancer. It lives in rg-statline (not in the
# MC_ node resource group), so its address stays the same when the cluster is re-created inside
# this stack. It is destroyed with the stack, like everything else in principal. The LB controller
# reads it through service.beta.kubernetes.io/azure-load-balancer-resource-group (plataforma).
resource "azurerm_public_ip" "ingress" {
  name                = "pip-${local.name}-ingress"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

# Cluster control-plane identity needs Network Contributor on the resource group that holds the
# public IP (AKS BYO public IP in another resource group). Scoped to the RG, as AKS documents.
resource "azurerm_role_assignment" "aks_ingress_pip" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Network Contributor"
  principal_id         = module.aks.identity_principal_id
}

module "plataforma" {
  source = "../modules/plataforma"

  ingress_public_ip_name = azurerm_public_ip.ingress.name
  resource_group_name    = azurerm_resource_group.main.name

  # The LB controller needs the role on the public IP resource group before it reconciles.
  depends_on = [azurerm_role_assignment.aks_ingress_pip]
}

# Optional: only when a domain is decided (variable dominio). The zone's name servers must be
# delegated at the registrar (see README).
module "dns" {
  source = "../modules/dns"
  count  = var.dominio == null ? 0 : 1

  dominio             = var.dominio
  resource_group_name = azurerm_resource_group.main.name
  ingress_public_ip   = azurerm_public_ip.ingress.ip_address
  tags                = local.tags
}

# ── Pending (second half, see docs/BACKLOG.md) ──────────────────────────────
#
# TODO(SL-09) module "seguridad": Key Vault (RBAC, purge protection), secrets DATABASE_URL
#   (module.datos.database_url), JWT_SECRET, JWT_REFRESH_SECRET, API_SPORTS_KEY, and
#   "Key Vault Secrets User" for module.aks.key_vault_csi_identity_object_id.
#
# TODO(SL-10) module "observabilidad": log_analytics_workspace + diagnostic_settings for AKS,
#   PostgreSQL and Key Vault; then wire oms_agent in module aks.
