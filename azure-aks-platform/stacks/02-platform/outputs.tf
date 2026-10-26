output "chart_versions" {
  value = module.platform_addons.chart_versions
}

output "addons" {
  value = module.platform_addons.addons
}

output "rbac_manifests_applied" {
  value = module.platform_addons.rbac_manifests_applied
}
