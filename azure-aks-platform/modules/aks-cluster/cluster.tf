resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = local.resource_group_name
  node_resource_group = local.node_resource_group_name
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier

  dns_prefix                 = local.byo_private_dns_zone ? null : var.cluster_name
  dns_prefix_private_cluster = local.byo_private_dns_zone ? var.cluster_name : null

  # Private API server only (equivalent of endpoint_private_access = true / public = false)
  private_cluster_enabled             = true
  private_dns_zone_id                 = var.private_dns_zone_id
  private_cluster_public_fqdn_enabled = var.private_cluster_public_fqdn_enabled

  # Entra ID auth + Azure RBAC, no static admin kubeconfig (replaces aws-auth configmap)
  local_account_disabled            = true
  role_based_access_control_enabled = true

  azure_active_directory_role_based_access_control {
    tenant_id              = data.azurerm_client_config.current.tenant_id
    admin_group_object_ids = var.admin_group_object_ids
    azure_rbac_enabled     = true
  }

  # Workload identity (replaces IRSA + OIDC provider)
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  automatic_upgrade_channel = var.automatic_upgrade_channel
  node_os_upgrade_channel   = var.node_os_upgrade_channel

  azure_policy_enabled         = var.enable_azure_policy
  image_cleaner_enabled        = true
  image_cleaner_interval_hours = var.image_cleaner_interval_hours
  run_command_enabled          = var.run_command_enabled
  cost_analysis_enabled        = var.sku_tier != "Free"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.control_plane.id]
  }

  # System pool replaces the Fargate profile that hosted Karpenter: dedicated to critical add-ons
  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_node_pool.vm_size
    zones                        = var.system_node_pool.zones
    vnet_subnet_id               = var.vnet_subnet_id
    orchestrator_version         = var.kubernetes_version
    os_sku                       = "AzureLinux"
    os_disk_type                 = var.system_node_pool.os_disk_type
    os_disk_size_gb              = var.system_node_pool.os_disk_size_gb
    max_pods                     = var.system_node_pool.max_pods
    only_critical_addons_enabled = true
    host_encryption_enabled      = var.host_encryption_enabled
    temporary_name_for_rotation  = "systemtmp"

    # Node Auto Provisioning cannot coexist with cluster-autoscaler
    auto_scaling_enabled = !local.nap_enabled
    node_count           = local.nap_enabled ? var.system_node_pool.node_count : null
    min_count            = local.nap_enabled ? null : var.system_node_pool.min_count
    max_count            = local.nap_enabled ? null : var.system_node_pool.max_count

    node_labels = {
      "nodepool-type" = "system"
    }

    upgrade_settings {
      max_surge                     = var.system_node_pool.max_surge
      drain_timeout_in_minutes      = 30
      node_soak_duration_in_minutes = 0
    }

    tags = local.tags
  }

  # Azure CNI Overlay + Cilium: pods don't consume VNet IPs, network policy is built in
  # (replaces vpc-cni with enableNetworkPolicy)
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    load_balancer_sku   = "standard"
    outbound_type       = var.network.outbound_type
    pod_cidr            = var.network.pod_cidr
    service_cidr        = var.network.service_cidr
    dns_service_ip      = var.network.dns_service_ip
  }

  # Managed Karpenter (replaces self-hosted Karpenter helm chart + IAM)
  dynamic "node_provisioning_profile" {
    for_each = local.nap_enabled ? [1] : []
    content {
      mode               = "Auto"
      default_node_pools = "None" # NodePools are defined in the node-provisioning module
    }
  }

  dynamic "auto_scaler_profile" {
    for_each = local.nap_enabled ? [] : [1]
    content {
      balance_similar_node_groups   = true
      expander                      = "least-waste"
      scale_down_unneeded           = "10m"
      scale_down_delay_after_add    = "10m"
      skip_nodes_with_local_storage = false
      max_graceful_termination_sec  = "600"
    }
  }

  # Managed Secrets Store CSI driver + Azure provider (replaces csi-secret-driver + csi-secret-provider-aws charts)
  dynamic "key_vault_secrets_provider" {
    for_each = var.enable_key_vault_secrets_provider ? [1] : []
    content {
      secret_rotation_enabled  = true
      secret_rotation_interval = var.secret_rotation_interval
    }
  }

  # Managed CSI drivers (replaces EBS/EFS CSI charts)
  storage_profile {
    disk_driver_enabled         = var.storage_drivers.disk_enabled
    file_driver_enabled         = var.storage_drivers.file_enabled
    blob_driver_enabled         = var.storage_drivers.blob_enabled
    snapshot_controller_enabled = var.storage_drivers.snapshot_controller_enabled
  }

  workload_autoscaler_profile {
    keda_enabled                    = var.enable_keda
    vertical_pod_autoscaler_enabled = var.enable_vpa
  }

  dynamic "key_management_service" {
    for_each = var.enable_kms_etcd_encryption ? [1] : []
    content {
      key_vault_key_id         = azurerm_key_vault_key.kms[0].id
      key_vault_network_access = var.kms_key_vault_network_access
    }
  }

  dynamic "oms_agent" {
    for_each = var.enable_container_insights ? [1] : []
    content {
      log_analytics_workspace_id      = local.log_analytics_workspace_id
      msi_auth_for_monitoring_enabled = true
    }
  }

  dynamic "monitor_metrics" {
    for_each = var.enable_managed_prometheus ? [1] : []
    content {}
  }

  dynamic "microsoft_defender" {
    for_each = var.enable_defender ? [1] : []
    content {
      log_analytics_workspace_id = local.log_analytics_workspace_id
    }
  }

  maintenance_window_auto_upgrade {
    frequency   = "Weekly"
    interval    = 1
    day_of_week = var.maintenance_window.day_of_week
    start_time  = var.maintenance_window.start_time
    duration    = var.maintenance_window.duration_hours
    utc_offset  = var.maintenance_window.utc_offset
  }

  maintenance_window_node_os {
    frequency   = "Weekly"
    interval    = 1
    day_of_week = var.maintenance_window.day_of_week
    start_time  = var.maintenance_window.start_time
    duration    = var.maintenance_window.duration_hours
    utc_offset  = var.maintenance_window.utc_offset
  }

  tags = local.tags

  lifecycle {
    precondition {
      condition     = !local.nap_enabled || var.system_node_pool.node_count >= 2
      error_message = "With node auto provisioning the system pool is not autoscaled; use node_count >= 2 (3 recommended across zones)."
    }
  }

  depends_on = [
    azurerm_role_assignment.control_plane_network,
    azurerm_role_assignment.control_plane_private_dns,
    azurerm_role_assignment.kms_control_plane,
  ]
}

# Protects the cluster from accidental deletion (replaces eks-resource-protection)
resource "azurerm_management_lock" "cluster" {
  count      = var.enable_delete_lock ? 1 : 0
  name       = "lock-${var.cluster_name}"
  scope      = azurerm_kubernetes_cluster.this.id
  lock_level = "CanNotDelete"
  notes      = "Managed by Terraform. Remove enable_delete_lock before deleting the cluster or its node pools."
}
