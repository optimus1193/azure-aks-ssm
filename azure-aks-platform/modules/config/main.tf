# Reads a customer's config.yaml and turns it into the inputs both stacks use.
# This is the contract between the hub and the spokes: naming, mandatory tags, feature
# defaults and which features may be toggled at all are decided here, not by the customer.

locals {
  raw = yamldecode(file(var.config_file))

  # Optional features and their hub defaults. Traefik and ArgoCD are core offerings and
  # deliberately not in this map, so a customer cannot switch them off.
  default_features = {
    # 01-cluster
    node_auto_provisioning     = true
    kms_etcd_encryption        = true
    defender                   = true
    azure_policy               = true
    delete_lock                = lower(try(local.raw.environment, "")) == "prod"
    key_vault_secrets_provider = true
    container_insights         = true
    managed_prometheus         = true
    keda                       = false
    vpa                        = false
    # 02-platform
    kyverno        = true
    reloader       = true
    rbac_manifests = true
  }
  core_offerings = ["traefik", "argocd"]

  # Allowed keys per section. Anything else is a typo or an unsupported option and fails the plan,
  # instead of being silently ignored.
  allowed_keys = {
    top = ["name", "environment", "subscription_id", "location", "tags", "features", "cluster", "platform"]
    cluster = [
      "name", "resource_group_name", "create_resource_group", "node_resource_group_name",
      "kubernetes_version", "sku_tier",
      "vnet_subnet_id", "additional_network_contributor_scopes", "network", "private_dns_zone_id", "private_cluster_public_fqdn_enabled",
      "system_node_pool", "user_node_pools", "host_encryption_enabled",
      "automatic_upgrade_channel", "node_os_upgrade_channel", "maintenance_window", "image_cleaner_interval_hours",
      "admin_group_object_ids", "cluster_role_assignments", "grant_deployer_cluster_admin", "acr_ids", "run_command_enabled",
      "kms_key_vault_network_access", "kms_private_endpoint", "secret_rotation_interval", "storage_drivers",
      "log_analytics_workspace_id", "log_retention_in_days", "log_daily_quota_gb", "control_plane_log_categories", "container_insights",
    ]
    platform = [
      "platform_key_vault_id", "helm_repository_override", "chart_versions", "ingress_class_name",
      "traefik", "argocd", "kyverno_dashboard_domain", "node_pools",
    ]
  }

  customer_features = try(local.raw.features, {})
  cluster           = try(local.raw.cluster, {})
  platform          = try(local.raw.platform, {})

  unknown_keys = concat(
    [for k in keys(local.raw) : k if !contains(local.allowed_keys.top, k)],
    [for k in keys(local.cluster) : "cluster.${k}" if !contains(local.allowed_keys.cluster, k)],
    [for k in keys(local.platform) : "platform.${k}" if !contains(local.allowed_keys.platform, k)],
    [for k in keys(local.customer_features) : "features.${k}" if !contains(keys(local.default_features), k) && !contains(local.core_offerings, k)],
  )
  toggled_core = [for k in keys(local.customer_features) : k if contains(local.core_offerings, k)]

  required = {
    "name"                           = try(local.raw.name, null)
    "environment"                    = try(local.raw.environment, null)
    "subscription_id"                = try(local.raw.subscription_id, null)
    "location"                       = try(local.raw.location, null)
    "cluster.kubernetes_version"     = try(local.cluster.kubernetes_version, null)
    "cluster.vnet_subnet_id"         = try(local.cluster.vnet_subnet_id, null)
    "platform.platform_key_vault_id" = try(local.platform.platform_key_vault_id, null)
    "platform.argocd.domain"         = try(local.platform.argocd.domain, null)
  }
  missing = [for k, v in local.required : k if v == null]

  name        = try(lower(local.raw.name), "")
  environment = try(lower(local.raw.environment), "")

  features = merge(local.default_features, {
    for k, v in local.customer_features : k => v if contains(keys(local.default_features), k)
  })

  # Naming convention owned by the hub; customers may override cluster/resource group names
  cluster_name        = try(local.cluster.name, "aks-${local.name}-${local.environment}")
  resource_group_name = try(local.cluster.resource_group_name, "rg-aks-${local.name}-${local.environment}")

  # Mandatory tags win over customer tags
  tags = merge(try(local.raw.tags, {}), {
    Environment = upper(local.environment)
    Application = local.name
    Created_By  = "Terraform"
    Managed_By  = "azure-aks-platform"
  })

  rbac_manifests_dir = local.features.rbac_manifests ? "${dirname(var.config_file)}/rbac" : null
}
