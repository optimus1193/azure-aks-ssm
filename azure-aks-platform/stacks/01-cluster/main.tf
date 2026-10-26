# Stage 1: Azure resources only. Every value comes from the customer's config.yaml;
# a key the customer leaves out falls back to the aks-cluster module default.

module "config" {
  source      = "../../modules/config"
  config_file = var.config_file
}

locals {
  s = module.config.settings
  c = local.s.cluster
  f = local.s.features
}

module "aks_cluster" {
  source = "../../modules/aks-cluster"

  cluster_name             = local.s.cluster_name
  environment              = local.s.environment
  location                 = local.s.location
  resource_group_name      = local.s.resource_group_name
  create_resource_group    = try(local.c.create_resource_group, null)
  node_resource_group_name = try(local.c.node_resource_group_name, null)
  kubernetes_version       = try(local.c.kubernetes_version, null) # required; checked by modules/config
  sku_tier                 = try(local.c.sku_tier, null)
  resource_tags            = local.s.tags

  # Networking
  vnet_subnet_id                        = try(local.c.vnet_subnet_id, null) # required; checked by modules/config
  additional_network_contributor_scopes = try(local.c.additional_network_contributor_scopes, null)
  network                               = try(local.c.network, null)
  private_dns_zone_id                   = try(local.c.private_dns_zone_id, null)
  private_cluster_public_fqdn_enabled   = try(local.c.private_cluster_public_fqdn_enabled, null)

  # Compute
  node_provisioning_mode  = local.f.node_auto_provisioning ? "Auto" : "Manual"
  system_node_pool        = try(local.c.system_node_pool, null)
  user_node_pools         = try(local.c.user_node_pools, null)
  host_encryption_enabled = try(local.c.host_encryption_enabled, null)

  # Upgrades & maintenance
  automatic_upgrade_channel    = try(local.c.automatic_upgrade_channel, null)
  node_os_upgrade_channel      = try(local.c.node_os_upgrade_channel, null)
  maintenance_window           = try(local.c.maintenance_window, null)
  image_cleaner_interval_hours = try(local.c.image_cleaner_interval_hours, null)

  # Identity & access
  admin_group_object_ids       = try(local.c.admin_group_object_ids, null)
  cluster_role_assignments     = try(local.c.cluster_role_assignments, null)
  grant_deployer_cluster_admin = try(local.c.grant_deployer_cluster_admin, null)
  acr_ids                      = try(local.c.acr_ids, null)
  run_command_enabled          = try(local.c.run_command_enabled, null)

  # Security
  enable_kms_etcd_encryption        = local.f.kms_etcd_encryption
  kms_key_vault_network_access      = try(local.c.kms_key_vault_network_access, null)
  kms_private_endpoint              = try(local.c.kms_private_endpoint, null)
  enable_azure_policy               = local.f.azure_policy
  enable_defender                   = local.f.defender
  enable_key_vault_secrets_provider = local.f.key_vault_secrets_provider
  secret_rotation_interval          = try(local.c.secret_rotation_interval, null)
  enable_delete_lock                = local.f.delete_lock

  # Managed add-ons
  storage_drivers = try(local.c.storage_drivers, null)
  enable_keda     = local.f.keda
  enable_vpa      = local.f.vpa

  # Observability
  log_analytics_workspace_id   = try(local.c.log_analytics_workspace_id, null)
  log_retention_in_days        = try(local.c.log_retention_in_days, null)
  log_daily_quota_gb           = try(local.c.log_daily_quota_gb, null)
  control_plane_log_categories = try(local.c.control_plane_log_categories, null)
  enable_container_insights    = local.f.container_insights
  container_insights           = try(local.c.container_insights, null)
  enable_managed_prometheus    = local.f.managed_prometheus
}
