output "chart_versions" {
  value = local.chart_versions
}

output "addons" {
  description = "Which add-ons this stack installs. traefik and argocd are core offerings and always true."
  value = {
    traefik  = true
    argocd   = true
    kyverno  = var.enable_kyverno
    reloader = var.enable_reloader
  }
}

output "argocd_repo_server_client_id" {
  value = local.argocd_wi ? module.argocd_workload_identity[0].client_id : null
}

output "rbac_manifests_applied" {
  value = keys(local.rbac_manifests)
}
