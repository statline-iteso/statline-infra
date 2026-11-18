output "log_analytics_workspace_id" {
  description = "Log Analytics workspace id (AKS oms_agent, diagnostic settings)."
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  description = "Log Analytics workspace name (log-statline)."
  value       = azurerm_log_analytics_workspace.main.name
}

output "diagnostic_setting_names" {
  description = "Diagnostic settings created, keyed by recursos_diagnostico key."
  value       = { for k, d in azurerm_monitor_diagnostic_setting.this : k => d.name }
}
