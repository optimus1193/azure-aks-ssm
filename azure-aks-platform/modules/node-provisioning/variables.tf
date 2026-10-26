variable "environment" {
  type        = string
  description = "In prod, pools default to on-demand capacity only; elsewhere spot is preferred with on-demand fallback"
}

variable "node_pools" {
  type = map(object({
    sku_families      = optional(list(string), ["D"])
    cpu_counts        = optional(list(string), ["4", "8", "16", "32"])
    architectures     = optional(list(string), ["amd64"])
    capacity_types    = optional(list(string)) # null = environment default
    extra_requirements = optional(list(object({
      key      = string
      operator = string
      values   = list(string)
    })), [])
    labels            = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = optional(string)
      effect = string
    })), [])
    weight            = optional(number, 10)
    cpu_limit         = optional(string, "1000")
    memory_limit      = optional(string)
    expire_after      = optional(string, "720h")
    consolidation_policy = optional(string, "WhenEmptyOrUnderutilized")
    consolidate_after = optional(string, "1m")
    disruption_budget = optional(string, "10%")
    image_family      = optional(string, "AzureLinux")
    os_disk_size_gb   = optional(number, 128)
  }))
  description = "Karpenter NodePool + AKSNodeClass pairs. Key = name used for both objects."
  default = {
    general = {}
  }
  nullable    = false
}

variable "resource_tags" {
  type        = map(string)
  description = "Tags applied to VMs created by node auto provisioning"
  default     = {}
  nullable    = false
}
