# Traefik behind an internal Azure Standard Load Balancer.
# Replaces traefik + aws_alb_controller + NLB target group bindings: AKS's cloud provider
# provisions the LB from the Service annotations, no extra controller needed.

locals {
  traefik_service_annotations = {
    for k, v in {
      "service.beta.kubernetes.io/azure-load-balancer-internal"        = var.traefik.internal ? "true" : null
      "service.beta.kubernetes.io/azure-load-balancer-internal-subnet" = var.traefik.lb_subnet_name
      "service.beta.kubernetes.io/azure-load-balancer-ipv4"            = var.traefik.lb_static_ip
    } : k => v if v != null
  }

  traefik_values = {
    deployment = {
      replicas = var.traefik.replicas
    }
    podDisruptionBudget = {
      enabled      = true
      minAvailable = 1
    }
    topologySpreadConstraints = [{
      maxSkew           = 1
      topologyKey       = "topology.kubernetes.io/zone"
      whenUnsatisfiable = "ScheduleAnyway"
      labelSelector = {
        matchLabels = { "app.kubernetes.io/name" = "traefik" }
      }
    }]
    resources = {
      requests = { cpu = "200m", memory = "256Mi" }
      limits   = { memory = "512Mi" }
    }
    ingressClass = {
      enabled        = true
      isDefaultClass = var.traefik.default_ingress
      name           = var.ingress_class_name
    }
    providers = {
      kubernetesIngress = {
        publishedService = { enabled = true }
      }
    }
    service = {
      annotations = local.traefik_service_annotations
      spec = {
        # keep client source IPs and avoid an extra hop between nodes
        externalTrafficPolicy = "Local"
      }
    }
    logs = {
      access = { enabled = true }
    }
  }
}

resource "helm_release" "traefik" {
  name             = "traefik"
  namespace        = "traefik"
  create_namespace = true
  repository       = local.repositories.traefik
  chart            = "traefik"
  version          = local.chart_versions.traefik
  atomic           = true
  cleanup_on_fail  = true
  max_history      = 5
  timeout          = 600

  values = [yamlencode(local.traefik_values)]
}
