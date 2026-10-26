variable "cluster_name" {
  description = "AKS cluster name."
  type        = string
}

variable "location" {
  description = "Azure region for AKS."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that will host the AKS cluster."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID used by AKS."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for AKS monitoring."
  type        = string
}

variable "dns_prefix" {
  description = "DNS prefix used by the AKS API server."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version to deploy."
  type        = string
}

variable "private_cluster_enabled" {
  description = "Whether to deploy the cluster as private."
  type        = bool
  default     = false
}

variable "authorized_ip_ranges" {
  description = "CIDR ranges allowed to access the Kubernetes API server."
  type        = list(string)
  default     = []
}

variable "ssh_public_key" {
  description = "Public SSH key for Linux node admin access."
  type        = string
}

variable "system_node_pool_name" {
  description = "System node pool name."
  type        = string
}

variable "system_node_count" {
  description = "Initial number of nodes in the system pool."
  type        = number
}

variable "system_node_vm_size" {
  description = "VM size for the system node pool."
  type        = string
}

variable "user_node_pool_name" {
  description = "User node pool name."
  type        = string
}

variable "user_node_count" {
  description = "Initial number of nodes in the user pool."
  type        = number
}

variable "user_node_vm_size" {
  description = "VM size for the user node pool."
  type        = string
}

variable "node_resource_group" {
  description = "AKS node resource group name."
  type        = string
}

variable "node_min_count" {
  description = "Minimum autoscaled nodes in the user pool."
  type        = number
  default     = 1
}

variable "node_max_count" {
  description = "Maximum autoscaled nodes in the user pool."
  type        = number
  default     = 5
}

variable "enable_user_pool_autoscaling" {
  description = "Enable autoscaling on the user node pool."
  type        = bool
  default     = true
}

variable "node_os_disk_size_gb" {
  description = "OS disk size for all AKS nodes."
  type        = number
  default     = 128
}

variable "tags" {
  description = "Tags applied to AKS resources."
  type        = map(string)
  default     = {}
}
