# Stage 2: everything inside Kubernetes. Values come from the customer's config.yaml.

module "config" {
  source      = "../../modules/config"
  config_file = var.config_file
}

locals {
  s = module.config.settings
  p = local.s.platform
  f = local.s.features
}

# Replaces the karpenter module's EC2NodeClass + NodePool.
# Follows features.node_auto_provisioning, the same switch 01-cluster uses for the cluster mode.
module "node_provisioning" {
  source = "../../modules/node-provisioning"
  count  = local.f.node_auto_provisioning ? 1 : 0

  environment   = local.s.environment
  resource_tags = local.s.tags
  node_pools    = try(local.p.node_pools, null)
}

# Traefik and ArgoCD are core offerings: always installed. Kyverno, Reloader and RBAC manifests are optional.
module "platform_addons" {
  source = "../../modules/platform-addons"

  cluster_name          = data.azurerm_kubernetes_cluster.this.name
  resource_group_name   = data.azurerm_kubernetes_cluster.this.resource_group_name
  location              = data.azurerm_kubernetes_cluster.this.location
  oidc_issuer_url       = data.azurerm_kubernetes_cluster.this.oidc_issuer_url
  resource_tags         = local.s.tags
  platform_key_vault_id = try(local.p.platform_key_vault_id, null) # required; checked by modules/config

  helm_repository_override = try(local.p.helm_repository_override, null)
  chart_versions           = try(local.p.chart_versions, null)
  ingress_class_name       = try(local.p.ingress_class_name, null)

  traefik = try(local.p.traefik, null)
  argocd  = try(local.p.argocd, null)

  enable_kyverno           = local.f.kyverno
  kyverno_dashboard_domain = try(local.p.kyverno_dashboard_domain, null)
  enable_reloader          = local.f.reloader
  rbac_manifests_dir       = local.s.rbac_manifests_dir

  # NodePools must exist so add-on pods can be scheduled off the tainted system pool
  depends_on = [module.node_provisioning]
}
