# aks: managed cluster (proposal §4.1) with a user-assigned control-plane identity, Azure CNI,
# Azure network policy (NetworkPolicy objects are enforced), the Key Vault Secrets Store CSI
# add-on and workload identity for the pods that read Key Vault.

resource "azurerm_user_assigned_identity" "aks" {
  name                = "id-${var.name}-aks"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# The control plane joins nodes and load balancers to the subnet.
resource "azurerm_role_assignment" "aks_network" {
  scope                = var.subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  dns_prefix          = var.name
  kubernetes_version  = var.kubernetes_version
  sku_tier            = "Free"

  default_node_pool {
    name                        = "system"
    vm_size                     = var.node_vm_size
    vnet_subnet_id              = var.subnet_id
    auto_scaling_enabled        = true
    min_count                   = var.node_min_count
    max_count                   = var.node_max_count
    os_disk_size_gb             = 64
    temporary_name_for_rotation = "systemtmp"

    upgrade_settings {
      max_surge = "1"
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
    # Must not overlap the VNet (10.0.0.0/16).
    service_cidr   = "10.1.0.0/16"
    dns_service_ip = "10.1.0.10"
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "5m"
  }

  # TODO(SL-10): oms_agent { log_analytics_workspace_id = … } once the observabilidad module exists.

  tags = var.tags

  depends_on = [azurerm_role_assignment.aks_network]
}
