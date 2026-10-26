# Optional static VMSS pools, e.g. for GPU or workloads that need a fixed SKU.
# With node auto provisioning these are fixed-size; in Manual mode they are autoscaled.
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  for_each = var.user_node_pools

  name                        = each.key
  kubernetes_cluster_id       = azurerm_kubernetes_cluster.this.id
  mode                        = "User"
  vm_size                     = each.value.vm_size
  zones                       = each.value.zones
  vnet_subnet_id              = coalesce(each.value.vnet_subnet_id, var.vnet_subnet_id)
  orchestrator_version        = var.kubernetes_version
  os_type                     = "Linux"
  os_sku                      = "AzureLinux"
  os_disk_type                = each.value.os_disk_type
  os_disk_size_gb             = each.value.os_disk_size_gb
  max_pods                    = each.value.max_pods
  host_encryption_enabled     = var.host_encryption_enabled
  temporary_name_for_rotation = "${substr(each.key, 0, 9)}tmp"

  auto_scaling_enabled = !local.nap_enabled
  node_count           = local.nap_enabled ? each.value.node_count : null
  min_count            = local.nap_enabled ? null : each.value.min_count
  max_count            = local.nap_enabled ? null : each.value.max_count

  priority        = each.value.spot ? "Spot" : "Regular"
  eviction_policy = each.value.spot ? "Delete" : null
  spot_max_price  = each.value.spot ? -1 : null

  node_labels = each.value.labels
  # AKS adds the spot taint itself; declaring it avoids a perpetual diff
  node_taints = concat(each.value.taints, each.value.spot ? ["kubernetes.azure.com/scalesetpriority=spot:NoSchedule"] : [])

  # Spot pools do not support surge upgrades
  dynamic "upgrade_settings" {
    for_each = each.value.spot ? [] : [1]
    content {
      max_surge                     = each.value.max_surge
      drain_timeout_in_minutes      = 30
      node_soak_duration_in_minutes = 0
    }
  }

  tags = local.tags
}
