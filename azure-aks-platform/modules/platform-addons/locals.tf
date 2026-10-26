# One map instead of a coalesce() ladder per Kubernetes version.
# Bump versions here (or per environment through var.chart_versions) after testing.
locals {
  default_chart_versions = {
    argocd          = "9.4.1"
    traefik         = "40.0.0"
    kyverno         = "3.7.1"
    policy_reporter = "3.7.2"
    reloader        = "2.2.8"
  }

  chart_versions = merge(local.default_chart_versions, var.chart_versions)

  upstream_repositories = {
    argocd          = "https://argoproj.github.io/argo-helm"
    traefik         = "https://traefik.github.io/charts"
    kyverno         = "https://kyverno.github.io/kyverno"
    policy_reporter = "https://kyverno.github.io/policy-reporter"
    reloader        = "https://stakater.github.io/stakater-charts"
  }

  repositories = {
    for k, v in local.upstream_repositories : k => coalesce(var.helm_repository_override, v)
  }
}
