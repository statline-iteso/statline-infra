# seguridad: Key Vault with Azure RBAC (no access policies) holding the application secrets.
# Secret names are a contract with the backend and the SecretProviderClass (docs/ARCHITECTURE.md §3).
# Values are generated here or copied from datos; api-sports-key is a placeholder set out of band.

data "azurerm_client_config" "current" {}

locals {
  environments = toset(["staging", "prod"])
}

resource "azurerm_key_vault" "main" {
  name                = "kv-${var.name}-${var.suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  rbac_authorization_enabled    = true
  soft_delete_retention_days    = 7
  purge_protection_enabled      = false # Students re-create the stack often; see DECISIONS D-18.
  public_network_access_enabled = true  # AKS CSI reads over the public endpoint (D-18).

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = var.tags
}

# Terraform writes the secrets as the deployer, so it needs data-plane write access.
resource "azurerm_role_assignment" "deployer_secrets_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# The Secrets Store CSI add-on (module aks) reads the secrets into the pods.
resource "azurerm_role_assignment" "csi_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.csi_identity_object_id
}

resource "random_password" "jwt_secret" {
  for_each = local.environments
  length   = 64
  special  = false
}

resource "random_password" "jwt_refresh_secret" {
  for_each = local.environments
  length   = 64
  special  = false
}

resource "azurerm_key_vault_secret" "database_url" {
  for_each     = local.environments
  name         = "database-url-${each.key}"
  value        = var.database_urls[each.key]
  key_vault_id = azurerm_key_vault.main.id
  content_type = "postgresql-connection-string"

  depends_on = [azurerm_role_assignment.deployer_secrets_officer]
}

resource "azurerm_key_vault_secret" "jwt_secret" {
  for_each     = local.environments
  name         = "jwt-secret-${each.key}"
  value        = random_password.jwt_secret[each.key].result
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"

  depends_on = [azurerm_role_assignment.deployer_secrets_officer]
}

resource "azurerm_key_vault_secret" "jwt_refresh_secret" {
  for_each     = local.environments
  name         = "jwt-refresh-secret-${each.key}"
  value        = random_password.jwt_refresh_secret[each.key].result
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"

  depends_on = [azurerm_role_assignment.deployer_secrets_officer]
}

# Placeholder only: the real API-Sports key is set in the portal or with `az keyvault secret set`,
# and Terraform never overwrites it afterwards.
resource "azurerm_key_vault_secret" "api_sports_key" {
  name         = "api-sports-key"
  value        = "set-me"
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"

  depends_on = [azurerm_role_assignment.deployer_secrets_officer]

  lifecycle {
    ignore_changes = [value]
  }
}
