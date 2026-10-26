# Every stack reads `settings`, so the checks below run before any resource is planned.
output "settings" {
  value = {
    name                = local.name
    environment         = local.environment
    subscription_id     = local.required.subscription_id
    location            = local.required.location
    cluster_name        = local.cluster_name
    resource_group_name = local.resource_group_name
    tags                = local.tags
    features            = local.features
    cluster             = local.cluster
    platform            = local.platform
    rbac_manifests_dir  = local.rbac_manifests_dir
  }

  precondition {
    condition     = length(local.missing) == 0
    error_message = "${var.config_file}: missing required keys: ${join(", ", local.missing)}."
  }
  precondition {
    condition     = length(local.toggled_core) == 0
    error_message = "${var.config_file}: ${join(", ", local.toggled_core)} are core offerings and always installed. Remove them from `features`; configure them under `platform` instead."
  }
  precondition {
    condition     = length(local.unknown_keys) == 0
    error_message = "${var.config_file}: unknown keys: ${join(", ", local.unknown_keys)}. See the azure-aks-platform README for the supported options."
  }
  precondition {
    condition     = can(regex("^[a-z][a-z0-9-]{0,20}$", local.name))
    error_message = "name must be lowercase letters, numbers and hyphens (max 21 chars); it is used in resource names."
  }
  precondition {
    condition     = alltrue([for v in values(local.features) : can(tobool(v))])
    error_message = "Every value under `features` must be true or false."
  }
}
