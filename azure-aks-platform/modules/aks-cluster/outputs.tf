output "cluster_name" {
  value = azurerm_kubernetes_cluster.this.name
}

output "cluster_id" {
  value = azurerm_kubernetes_cluster.this.id
}

output "resource_group_name" {
  value = local.resource_group_name
}

output "node_resource_group_name" {
  value = azurerm_kubernetes_cluster.this.node_resource_group
}

output "kubernetes_version" {
  value = azurerm_kubernetes_cluster.this.current_kubernetes_version
}

output "private_fqdn" {
  value = azurerm_kubernetes_cluster.this.private_fqdn
}

output "oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "kubelet_identity_object_id" {
  value = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

output "control_plane_identity_principal_id" {
  value = azurerm_user_assigned_identity.control_plane.principal_id
}

output "key_vault_secrets_provider_client_id" {
  value = var.enable_key_vault_secrets_provider ? azurerm_kubernetes_cluster.this.key_vault_secrets_provider[0].secret_identity[0].client_id : null
}

output "log_analytics_workspace_id" {
  value = local.log_analytics_workspace_id
}

output "monitor_workspace_id" {
  value = var.enable_managed_prometheus ? azurerm_monitor_workspace.prometheus[0].id : null
}

output "kms_key_vault_id" {
  value = var.enable_kms_etcd_encryption ? azurerm_key_vault.kms[0].id : null
}

output "node_provisioning_enabled" {
  value = local.nap_enabled
}
