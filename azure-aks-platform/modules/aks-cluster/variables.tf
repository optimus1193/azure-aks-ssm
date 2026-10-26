############################################
# Core
############################################

variable "cluster_name" {
  type        = string
  description = "Name of the AKS cluster. Recommended format: aks-<appname>-<envname>"
  validation {
    condition     = can(regex("^aks-[a-z0-9-]{1,40}[a-z0-9]$", var.cluster_name))
    error_message = "Cluster name must start with 'aks-', contain only lowercase letters, numbers and hyphens, end with a letter or number and be at most 45 chars."
  }
}

variable "environment" {
  type        = string
  description = "Environment name (dev, test, uat, preprod, prod). 'prod' switches on stricter defaults."
  validation {
    condition     = contains(["dev", "test", "uat", "preprod", "prod"], lower(var.environment))
    error_message = "environment must be one of: dev, test, uat, preprod, prod."
  }
}

variable "location" {
  type        = string
  description = "Azure region for the cluster, e.g. southafricanorth"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group that holds the cluster and its supporting resources"
}

variable "create_resource_group" {
  type        = bool
  description = "Create resource_group_name. Set false to use an existing resource group."
  default     = true
  nullable    = false
}

variable "node_resource_group_name" {
  type        = string
  description = "Name of the AKS-managed node resource group. Defaults to rg-<cluster_name>-nodes."
  default     = null
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes minor version (e.g. 1.35). Patch versions are applied by the auto-upgrade channel."
  validation {
    condition     = can(regex("^1\\.[0-9]{2}$", var.kubernetes_version))
    error_message = "kubernetes_version must be a minor version such as 1.35 (no patch). Check `az aks get-versions -l <region>`."
  }
}

variable "sku_tier" {
  type        = string
  description = "AKS control plane tier. Standard gives the uptime SLA and is required for production."
  default     = "Standard"
  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku_tier)
    error_message = "sku_tier must be one of Free, Standard, Premium."
  }
  nullable    = false
}

variable "resource_tags" {
  type        = map(string)
  description = "Tags applied to every Azure resource created by this module"
  default     = {}
  nullable    = false
}

############################################
# Networking (bring-your-own VNet)
############################################

variable "vnet_subnet_id" {
  type        = string
  description = "Subnet ID for the system node pool (and default for user pools / node auto provisioning)"
}

variable "additional_network_contributor_scopes" {
  type        = list(string)
  description = "Extra scopes (route tables, ingress subnets, public IPs) the control plane identity needs Network Contributor on"
  default     = []
  nullable    = false
}

variable "network" {
  type = object({
    outbound_type  = optional(string, "loadBalancer")
    pod_cidr       = optional(string, "10.244.0.0/16")
    service_cidr   = optional(string, "172.16.0.0/16")
    dns_service_ip = optional(string, "172.16.0.10")
  })
  description = "Azure CNI Overlay + Cilium settings. Pod/service CIDRs must not overlap with any routable network."
  default     = {}
  validation {
    condition     = contains(["loadBalancer", "userDefinedRouting", "managedNATGateway", "userAssignedNATGateway"], var.network.outbound_type)
    error_message = "network.outbound_type must be one of loadBalancer, userDefinedRouting, managedNATGateway, userAssignedNATGateway."
  }
  nullable    = false
}

variable "private_dns_zone_id" {
  type        = string
  description = "Private DNS zone for the private API server: 'System', 'None', or the resource ID of a BYO privatelink.<region>.azmk8s.io zone (hub-spoke)."
  default     = "System"
  nullable    = false
}

variable "private_cluster_public_fqdn_enabled" {
  type        = bool
  description = "Also publish a public FQDN (resolving to the private IP) for the API server"
  default     = false
  nullable    = false
}

############################################
# Compute
############################################

variable "node_provisioning_mode" {
  type        = string
  description = "'Auto' = Node Auto Provisioning (managed Karpenter) for workloads; 'Manual' = cluster-autoscaler on user_node_pools."
  default     = "Auto"
  validation {
    condition     = contains(["Auto", "Manual"], var.node_provisioning_mode)
    error_message = "node_provisioning_mode must be Auto or Manual."
  }
  nullable    = false
}

variable "system_node_pool" {
  type = object({
    vm_size         = optional(string, "Standard_D4ds_v5")
    zones           = optional(list(string), ["1", "2", "3"])
    node_count      = optional(number, 3) # used when node_provisioning_mode = Auto (autoscaler must be off)
    min_count       = optional(number, 3) # used when node_provisioning_mode = Manual
    max_count       = optional(number, 6)
    max_pods        = optional(number, 110)
    os_disk_type    = optional(string, "Ephemeral")
    os_disk_size_gb = optional(number, 128)
    max_surge       = optional(string, "33%")
  })
  description = "System node pool (runs CoreDNS, konnectivity, metrics-server, NAP controller). Tainted CriticalAddonsOnly."
  default     = {}
  nullable    = false
}

variable "user_node_pools" {
  type = map(object({
    vm_size         = string
    zones           = optional(list(string), ["1", "2", "3"])
    vnet_subnet_id  = optional(string)
    node_count      = optional(number, 3)
    min_count       = optional(number, 1)
    max_count       = optional(number, 10)
    max_pods        = optional(number, 110)
    os_disk_type    = optional(string, "Ephemeral")
    os_disk_size_gb = optional(number, 128)
    spot            = optional(bool, false)
    labels          = optional(map(string), {})
    taints          = optional(list(string), [])
    max_surge       = optional(string, "33%")
  }))
  description = "Optional static VMSS user node pools. Key = pool name (max 12 lowercase alphanumerics)."
  default     = {}
  validation {
    condition     = alltrue([for k in keys(var.user_node_pools) : can(regex("^[a-z][a-z0-9]{0,11}$", k))])
    error_message = "user_node_pools keys must be 1-12 lowercase alphanumerics starting with a letter."
  }
  nullable    = false
}

variable "host_encryption_enabled" {
  type        = bool
  description = "Encrypt node temp/cache disks at host. Requires the Microsoft.Compute/EncryptionAtHost feature on the subscription."
  default     = false
  nullable    = false
}

############################################
# Upgrades & maintenance
############################################

variable "automatic_upgrade_channel" {
  type        = string
  description = "Control plane auto-upgrade channel. Only 'patch' or 'none' are allowed so minor upgrades stay under Terraform control."
  default     = "patch"
  validation {
    condition     = contains(["patch", "none"], var.automatic_upgrade_channel)
    error_message = "automatic_upgrade_channel must be 'patch' or 'none'. Minor upgrades are done by bumping kubernetes_version."
  }
  nullable    = false
}

variable "node_os_upgrade_channel" {
  type        = string
  description = "Node OS image/security patch channel"
  default     = "NodeImage"
  validation {
    condition     = contains(["NodeImage", "SecurityPatch", "Unmanaged", "None"], var.node_os_upgrade_channel)
    error_message = "node_os_upgrade_channel must be one of NodeImage, SecurityPatch, Unmanaged, None."
  }
  nullable    = false
}

variable "maintenance_window" {
  type = object({
    day_of_week    = optional(string, "Sunday")
    start_time     = optional(string, "02:00")
    duration_hours = optional(number, 4)
    utc_offset     = optional(string, "+00:00")
  })
  description = "Weekly window used for both control plane patch upgrades and node OS upgrades"
  default     = {}
  nullable    = false
}

variable "image_cleaner_interval_hours" {
  type        = number
  description = "How often Image Cleaner removes unused images from nodes"
  default     = 48
  nullable    = false
}

############################################
# Identity & access
############################################

variable "admin_group_object_ids" {
  type        = list(string)
  description = "Entra ID group object IDs that get cluster-admin (equivalent of system:masters in aws-auth)"
  default     = []
  nullable    = false
}

variable "cluster_role_assignments" {
  type = map(object({
    principal_id   = string
    role           = string
    namespace      = optional(string)
    principal_type = optional(string, "Group")
  }))
  description = "Azure RBAC for Kubernetes assignments (replaces aws-auth mapRoles). Set namespace to scope the role to one namespace."
  default     = {}
  validation {
    condition = alltrue([for a in var.cluster_role_assignments : contains([
      "Azure Kubernetes Service RBAC Cluster Admin",
      "Azure Kubernetes Service RBAC Admin",
      "Azure Kubernetes Service RBAC Writer",
      "Azure Kubernetes Service RBAC Reader",
    ], a.role)])
    error_message = "role must be one of the 'Azure Kubernetes Service RBAC *' built-in roles."
  }
  nullable    = false
}

variable "grant_deployer_cluster_admin" {
  type        = bool
  description = "Give the identity running Terraform cluster-admin so the platform stack can deploy add-ons"
  default     = true
  nullable    = false
}

variable "acr_ids" {
  type        = list(string)
  description = "Azure Container Registry IDs the kubelet identity gets AcrPull on"
  default     = []
  nullable    = false
}

variable "run_command_enabled" {
  type        = bool
  description = "Allow `az aks command invoke` (break-glass access to a private cluster)"
  default     = false
  nullable    = false
}

############################################
# Security
############################################

variable "enable_kms_etcd_encryption" {
  type        = bool
  description = "Encrypt Kubernetes secrets in etcd with a customer-managed Key Vault key"
  default     = true
  nullable    = false
}

variable "kms_key_vault_network_access" {
  type        = string
  description = "'Public' (Key Vault reachable publicly, protected by RBAC) or 'Private' (public access disabled; requires kms_private_endpoint for the Terraform runner)"
  default     = "Public"
  validation {
    condition     = contains(["Public", "Private"], var.kms_key_vault_network_access)
    error_message = "kms_key_vault_network_access must be Public or Private."
  }
  nullable    = false
}

variable "kms_private_endpoint" {
  type = object({
    subnet_id           = string
    private_dns_zone_id = optional(string)
  })
  description = "Private endpoint for the KMS Key Vault so the Terraform runner can manage the key when access is Private"
  default     = null
}

variable "enable_azure_policy" {
  type        = bool
  description = "Enable the Azure Policy add-on (Gatekeeper)"
  default     = true
  nullable    = false
}

variable "enable_defender" {
  type        = bool
  description = "Enable Microsoft Defender for Containers sensor"
  default     = true
  nullable    = false
}

variable "enable_key_vault_secrets_provider" {
  type        = bool
  description = "Enable the managed Secrets Store CSI driver with the Azure Key Vault provider"
  default     = true
  nullable    = false
}

variable "secret_rotation_interval" {
  type        = string
  description = "Polling interval for Key Vault secret rotation"
  default     = "2m"
  nullable    = false
}

variable "enable_delete_lock" {
  type        = bool
  description = "Put a CanNotDelete management lock on the cluster. Node pools cannot be removed while it is in place."
  default     = false
  nullable    = false
}

############################################
# Add-ons
############################################

variable "storage_drivers" {
  type = object({
    disk_enabled                = optional(bool, true)
    file_enabled                = optional(bool, true)
    blob_enabled                = optional(bool, false)
    snapshot_controller_enabled = optional(bool, true)
  })
  description = "Managed CSI drivers (replaces EBS/EFS CSI helm charts)"
  default     = {}
  nullable    = false
}

variable "enable_keda" {
  type        = bool
  description = "Enable the managed KEDA add-on"
  default     = false
  nullable    = false
}

variable "enable_vpa" {
  type        = bool
  description = "Enable the managed Vertical Pod Autoscaler"
  default     = false
  nullable    = false
}

############################################
# Observability
############################################

variable "log_analytics_workspace_id" {
  type        = string
  description = "Existing Log Analytics workspace ID. If null a workspace is created for the cluster."
  default     = null
}

variable "log_retention_in_days" {
  type        = number
  description = "Retention for the created Log Analytics workspace"
  default     = 90
  validation {
    condition     = var.log_retention_in_days >= 30 && var.log_retention_in_days <= 730
    error_message = "log_retention_in_days must be between 30 and 730."
  }
  nullable    = false
}

variable "log_daily_quota_gb" {
  type        = number
  description = "Daily ingestion cap for the created workspace (-1 = unlimited)"
  default     = -1
  nullable    = false
}

variable "control_plane_log_categories" {
  type        = list(string)
  description = "Control plane log categories sent to Log Analytics. kube-audit-admin is much cheaper than kube-audit."
  default     = ["kube-apiserver", "kube-audit-admin", "kube-controller-manager", "kube-scheduler", "cluster-autoscaler", "guard"]
  validation {
    condition = alltrue([for c in var.control_plane_log_categories : contains([
      "kube-apiserver", "kube-audit", "kube-audit-admin", "kube-controller-manager", "kube-scheduler",
      "cluster-autoscaler", "cloud-controller-manager", "guard",
      "csi-azuredisk-controller", "csi-azurefile-controller", "csi-snapshot-controller",
    ], c)])
    error_message = "Invalid control plane log category."
  }
  nullable    = false
}

variable "enable_container_insights" {
  type        = bool
  description = "Collect container logs/inventory with Container Insights (ContainerLogV2)"
  default     = true
  nullable    = false
}

variable "container_insights" {
  type = object({
    streams            = optional(list(string), ["Microsoft-ContainerLogV2", "Microsoft-KubeEvents", "Microsoft-KubePodInventory", "Microsoft-KubeNodeInventory", "Microsoft-KubePVInventory", "Microsoft-KubeServices", "Microsoft-KubeMonAgentEvents"])
    interval           = optional(string, "1m")
    excluded_namespaces = optional(list(string), ["kube-system", "gatekeeper-system", "kube-node-lease", "kube-public"])
  })
  description = "Container Insights data collection settings. Perf/InsightsMetrics are left out by default because Managed Prometheus covers metrics."
  default     = {}
  nullable    = false
}

variable "enable_managed_prometheus" {
  type        = bool
  description = "Scrape metrics into an Azure Monitor workspace (Managed Prometheus)"
  default     = true
  nullable    = false
}
