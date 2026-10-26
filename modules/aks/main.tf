resource "azurerm_kubernetes_cluster" "main" {
  name                              = var.cluster_name
  location                          = var.location
  resource_group_name               = var.resource_group_name
  dns_prefix                       = var.dns_prefix
  kubernetes_version               = var.kubernetes_version
  node_resource_group              = var.node_resource_group
  private_cluster_enabled          = var.private_cluster_enabled
  role_based_access_control_enabled = true
  azure_policy_enabled             = true
  oidc_issuer_enabled             = true
  workload_identity_enabled        = true
  automatic_upgrade_channel        = "patch"
  sku_tier                         = "Free"
  tags                             = var.tags

  default_node_pool {
    name                 = var.system_node_pool_name
    node_count          = var.system_node_count
    vm_size             = var.system_node_vm_size
    os_disk_size_gb     = var.node_os_disk_size_gb
    type                = "VirtualMachineScaleSets"
    vnet_subnet_id      = var.subnet_id
    only_critical_addons_enabled = true
    zones               = ["1", "2", "3"]
  }

  identity {
    type = "SystemAssigned"
  }

  linux_profile {
    admin_username = "azureuser"

    ssh_key {
      key_data = var.ssh_public_key
    }
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"
    service_cidr      = "10.2.0.0/24"
    dns_service_ip    = "10.2.0.10"
    pod_cidr          = "10.244.0.0/16"
  }

  api_server_access_profile {
    authorized_ip_ranges = var.authorized_ip_ranges
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
    secret_rotation_interval = "2m"
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = var.user_node_pool_name
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.user_node_vm_size
  node_count            = var.user_node_count
  os_disk_size_gb       = var.node_os_disk_size_gb
  mode                  = "User"
  os_sku                = "AzureLinux"
  vnet_subnet_id        = var.subnet_id
  enable_auto_scaling   = var.enable_user_pool_autoscaling
  min_count             = var.node_min_count
  max_count             = var.node_max_count
  zones                 = ["1", "2", "3"]
  tags                  = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "${var.cluster_name}-diag"
  target_resource_id         = azurerm_kubernetes_cluster.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "kube-apiserver"
  }

  enabled_log {
    category = "kube-audit"
  }

  enabled_log {
    category = "kube-audit-admin"
  }

  enabled_log {
    category = "kube-controller-manager"
  }

  enabled_log {
    category = "kube-scheduler"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
