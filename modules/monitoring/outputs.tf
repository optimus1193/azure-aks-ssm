output "workspace_id" {
  description = "Log Analytics workspace ID used by AKS monitoring."
  value       = azurerm_log_analytics_workspace.aks.id
}

output "workspace_name" {
  description = "Log Analytics workspace name."
  value       = azurerm_log_analytics_workspace.aks.name
}

output "workspace_customer_id" {
  description = "Log Analytics customer ID."
  value       = azurerm_log_analytics_workspace.aks.workspace_id
}

output "workspace_primary_key" {
  description = "Log Analytics primary shared key."
  value       = azurerm_log_analytics_workspace.aks.primary_shared_key
  sensitive   = true
}
