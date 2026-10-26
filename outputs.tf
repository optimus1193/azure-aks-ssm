output "resource_group_name" {
  description = "Resource group created for the AKS environment."
  value       = azurerm_resource_group.main.name
}

output "aks_cluster_name" {
  description = "AKS cluster name."
  value       = module.aks.cluster_name
}

output "aks_cluster_id" {
  description = "AKS cluster resource ID."
  value       = module.aks.cluster_id
}

output "aks_fqdn" {
  description = "AKS API server FQDN."
  value       = module.aks.cluster_fqdn
}

output "aks_kubeconfig" {
  description = "Kubernetes configuration used to access the cluster."
  value       = module.aks.kube_config_raw
  sensitive   = true
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID used for AKS monitoring."
  value       = module.monitoring.workspace_id
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for AKS workload identity integration."
  value       = module.aks.oidc_issuer_url
}
