output "cluster_name" {
  value = module.aks_cluster.cluster_name
}

output "resource_group_name" {
  value = module.aks_cluster.resource_group_name
}

output "kubernetes_version" {
  value = module.aks_cluster.kubernetes_version
}

output "private_fqdn" {
  value = module.aks_cluster.private_fqdn
}

output "oidc_issuer_url" {
  value = module.aks_cluster.oidc_issuer_url
}

output "log_analytics_workspace_id" {
  value = module.aks_cluster.log_analytics_workspace_id
}

output "features" {
  value = local.f
}
