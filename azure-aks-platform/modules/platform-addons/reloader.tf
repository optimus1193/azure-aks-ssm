resource "helm_release" "reloader" {
  count            = var.enable_reloader ? 1 : 0
  name             = "reloader"
  namespace        = "reloader"
  create_namespace = true
  repository       = local.repositories.reloader
  chart            = "reloader"
  version          = local.chart_versions.reloader
  atomic           = true
  cleanup_on_fail  = true
  max_history      = 5
  timeout          = 600

  values = [yamlencode({
    reloader = {
      enableHA = true
      deployment = {
        replicas = 2
      }
    }
  })]
}
