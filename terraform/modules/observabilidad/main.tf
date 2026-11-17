# observabilidad: one Log Analytics workspace (log-statline, 30 days, daily cap to protect the
# student credit) and diagnostic settings that send logs and metrics of the other modules to it.
# The workspace has no dependencies, so modules aks and datos can take its id (oms_agent) while
# this module takes their resource ids (diagnostics) without a cycle.

resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_days
  daily_quota_gb      = var.daily_quota_gb
  tags                = var.tags
}

# Categories and metrics each resource supports. Used to check explicit category lists at plan
# time and to pick the allLogs group when a resource has no explicit list.
data "azurerm_monitor_diagnostic_categories" "this" {
  for_each    = var.recursos_diagnostico
  resource_id = each.value.resource_id
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each = var.recursos_diagnostico

  name                           = "diag-${each.key}"
  target_resource_id             = each.value.resource_id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.main.id
  log_analytics_destination_type = "Dedicated"

  # null: every log category group the resource offers (allLogs).
  dynamic "enabled_log" {
    for_each = each.value.log_categories == null ? toset(["allLogs"]) : toset([])
    content {
      category_group = enabled_log.value
    }
  }

  # Explicit list: only these categories (cheap defaults in principal, see DECISIONS D-16).
  dynamic "enabled_log" {
    for_each = each.value.log_categories == null ? toset([]) : toset(each.value.log_categories)
    content {
      category = enabled_log.value
    }
  }

  dynamic "metric" {
    for_each = each.value.metrics && contains(data.azurerm_monitor_diagnostic_categories.this[each.key].metrics, "AllMetrics") ? toset(["AllMetrics"]) : toset([])
    content {
      category = metric.value
      enabled  = true
    }
  }

  lifecycle {
    precondition {
      condition = alltrue([
        for c in coalesce(each.value.log_categories, []) :
        contains(data.azurerm_monitor_diagnostic_categories.this[each.key].log_category_types, c)
      ])
      error_message = "Some log categories in recursos_diagnostico[\"${each.key}\"] are not supported by the resource. Check the names with az monitor diagnostic-settings categories list."
    }
  }
}
