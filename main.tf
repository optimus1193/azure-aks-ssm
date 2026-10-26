resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

module "network" {
  source = "./modules/network"

  name                 = var.cluster_name
  location             = var.location
  resource_group_name  = azurerm_resource_group.main.name
  vnet_address_space   = var.vnet_address_space
  subnet_address_prefixes = var.subnet_address_prefixes
  tags                = local.tags
}

module "monitoring" {
  source = "./modules/monitoring"

  name                = var.cluster_name
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

module "aks" {
  source = "./modules/aks"

  cluster_name                = var.cluster_name
  location                   = var.location
  resource_group_name        = azurerm_resource_group.main.name
  subnet_id                  = module.network.subnet_id
  log_analytics_workspace_id = module.monitoring.workspace_id
  dns_prefix                 = var.dns_prefix
  kubernetes_version         = var.kubernetes_version
  private_cluster_enabled     = var.private_cluster_enabled
  authorized_ip_ranges       = var.authorized_ip_ranges
  ssh_public_key             = var.ssh_public_key
  system_node_pool_name      = var.system_node_pool_name
  system_node_count          = var.system_node_count
  system_node_vm_size        = var.system_node_vm_size
  user_node_pool_name        = var.user_node_pool_name
  user_node_count            = var.user_node_count
  user_node_vm_size          = var.user_node_vm_size
  node_min_count             = var.node_min_count
  node_max_count             = var.node_max_count
  enable_user_pool_autoscaling = var.enable_user_pool_autoscaling
  node_os_disk_size_gb       = var.node_os_disk_size_gb
  node_resource_group        = "${var.resource_group_name}-nodes"
  tags                       = local.tags
}
