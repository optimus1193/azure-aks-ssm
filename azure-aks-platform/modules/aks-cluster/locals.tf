data "azurerm_client_config" "current" {}

locals {
  nap_enabled = var.node_provisioning_mode == "Auto"

  resource_group_name      = var.create_resource_group ? azurerm_resource_group.this[0].name : var.resource_group_name
  node_resource_group_name = coalesce(var.node_resource_group_name, "rg-${var.cluster_name}-nodes")

  log_analytics_workspace_id = var.log_analytics_workspace_id != null ? var.log_analytics_workspace_id : azurerm_log_analytics_workspace.this[0].id

  # BYO private DNS zone (hub-spoke) needs dns_prefix_private_cluster and a role assignment
  byo_private_dns_zone = !contains(["System", "None"], var.private_dns_zone_id)

  # Every subnet nodes can land in must be joinable by the control plane identity
  network_contributor_scopes = toset(distinct(concat(
    [var.vnet_subnet_id],
    [for p in var.user_node_pools : p.vnet_subnet_id if p.vnet_subnet_id != null],
    var.additional_network_contributor_scopes,
  )))

  tags = merge(
    {
      ClusterName = var.cluster_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.resource_tags,
  )
}

resource "azurerm_resource_group" "this" {
  count    = var.create_resource_group ? 1 : 0
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}
