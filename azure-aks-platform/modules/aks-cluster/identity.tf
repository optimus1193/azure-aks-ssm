# Control plane identity (replaces the EKS control plane IAM role).
# User-assigned so role assignments exist before the cluster is created.
resource "azurerm_user_assigned_identity" "control_plane" {
  name                = "id-${var.cluster_name}-control-plane"
  location            = var.location
  resource_group_name = local.resource_group_name
  tags                = local.tags
}

resource "azurerm_role_assignment" "control_plane_network" {
  for_each             = local.network_contributor_scopes
  scope                = each.value
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "control_plane_private_dns" {
  count                = local.byo_private_dns_zone ? 1 : 0
  scope                = var.private_dns_zone_id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
  principal_type       = "ServicePrincipal"
}
