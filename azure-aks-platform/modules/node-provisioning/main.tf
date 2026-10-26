# NodePools for AKS Node Auto Provisioning (managed Karpenter).
# Replaces the EC2NodeClass/NodePool manifests of the karpenter module. Manifests are
# rendered with yamlencode instead of string templates so values are always valid YAML.

locals {
  default_capacity_types = lower(var.environment) == "prod" ? ["on-demand"] : ["spot", "on-demand"]
}

resource "kubectl_manifest" "node_class" {
  for_each = var.node_pools

  server_side_apply = true
  yaml_body = yamlencode({
    apiVersion = "karpenter.azure.com/v1beta1"
    kind       = "AKSNodeClass"
    metadata = {
      name = each.key
    }
    spec = {
      imageFamily  = each.value.image_family
      osDiskSizeGB = each.value.os_disk_size_gb
      tags         = var.resource_tags
    }
  })
}

resource "kubectl_manifest" "node_pool" {
  for_each = var.node_pools

  server_side_apply = true
  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = each.key
    }
    spec = {
      weight = each.value.weight
      template = {
        metadata = {
          labels = each.value.labels
        }
        spec = {
          nodeClassRef = {
            group = "karpenter.azure.com"
            kind  = "AKSNodeClass"
            name  = each.key
          }
          expireAfter = each.value.expire_after
          requirements = concat([
            { key = "karpenter.azure.com/sku-family", operator = "In", values = each.value.sku_families },
            { key = "karpenter.azure.com/sku-cpu", operator = "In", values = each.value.cpu_counts },
            { key = "kubernetes.io/arch", operator = "In", values = each.value.architectures },
            { key = "karpenter.sh/capacity-type", operator = "In", values = each.value.capacity_types != null ? each.value.capacity_types : local.default_capacity_types },
          ], each.value.extra_requirements)
          taints = [for t in each.value.taints : { for k, v in t : k => v if v != null }]
        }
      }
      limits = { for k, v in { cpu = each.value.cpu_limit, memory = each.value.memory_limit } : k => v if v != null }
      disruption = {
        consolidationPolicy = each.value.consolidation_policy
        consolidateAfter    = each.value.consolidate_after
        budgets             = [{ nodes = each.value.disruption_budget }]
      }
    }
  })

  depends_on = [kubectl_manifest.node_class]
}
