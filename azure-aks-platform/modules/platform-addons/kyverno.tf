resource "helm_release" "kyverno" {
  count            = var.enable_kyverno ? 1 : 0
  name             = "kyverno"
  namespace        = "kyverno"
  create_namespace = true
  repository       = local.repositories.kyverno
  chart            = "kyverno"
  version          = local.chart_versions.kyverno
  atomic           = true
  cleanup_on_fail  = true
  max_history      = 5
  timeout          = 900

  # HA layout recommended by Kyverno for production
  values = [yamlencode({
    admissionController = {
      replicas            = 3
      podDisruptionBudget = { enabled = true }
    }
    backgroundController = {
      replicas            = 2
      podDisruptionBudget = { enabled = true }
    }
    cleanupController = {
      replicas            = 2
      podDisruptionBudget = { enabled = true }
    }
    reportsController = {
      replicas            = 2
      podDisruptionBudget = { enabled = true }
    }
  })]
}

resource "helm_release" "policy_reporter" {
  count            = var.enable_kyverno ? 1 : 0
  name             = "policy-reporter"
  namespace        = "policy-reporter"
  create_namespace = true
  repository       = local.repositories.policy_reporter
  chart            = "policy-reporter"
  version          = local.chart_versions.policy_reporter
  atomic           = true
  cleanup_on_fail  = true
  max_history      = 5
  timeout          = 600

  values = [yamlencode({
    plugin = {
      kyverno = { enabled = true }
    }
    ui = {
      enabled = true
      ingress = {
        enabled   = var.kyverno_dashboard_domain != null
        className = var.ingress_class_name
        hosts = var.kyverno_dashboard_domain == null ? [] : [{
          host  = var.kyverno_dashboard_domain
          paths = [{ path = "/", pathType = "Prefix" }]
        }]
      }
    }
  })]

  depends_on = [helm_release.kyverno, helm_release.traefik]
}
