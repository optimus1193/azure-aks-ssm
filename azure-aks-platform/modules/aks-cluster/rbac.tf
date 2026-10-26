############################################
# Azure RBAC for Kubernetes (replaces the hard-coded aws-auth mapRoles)
############################################

# Terraform runner -> cluster-admin (equivalent of clusterAdminRoleName in system:masters)
resource "azurerm_role_assignment" "deployer_cluster_admin" {
  count                = var.grant_deployer_cluster_admin ? 1 : 0
  scope                = azurerm_kubernetes_cluster.this.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "cluster_rbac" {
  for_each             = var.cluster_role_assignments
  scope                = each.value.namespace == null ? azurerm_kubernetes_cluster.this.id : "${azurerm_kubernetes_cluster.this.id}/namespaces/${each.value.namespace}"
  role_definition_name = each.value.role
  principal_id         = each.value.principal_id
  principal_type       = each.value.principal_type
}

# Everyone with a Kubernetes role also needs to be able to fetch a kubeconfig
resource "azurerm_role_assignment" "cluster_user" {
  for_each             = toset(distinct(concat(var.admin_group_object_ids, [for a in var.cluster_role_assignments : a.principal_id])))
  scope                = azurerm_kubernetes_cluster.this.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = each.value
}

# Image pulls from ACR (replaces AmazonEC2ContainerRegistryReadOnly on the node role)
resource "azurerm_role_assignment" "kubelet_acr_pull" {
  for_each             = toset(var.acr_ids)
  scope                = each.value
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
  principal_type       = "ServicePrincipal"
}
