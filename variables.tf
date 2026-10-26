variable "subscription_id" {
  description = "Azure subscription ID. Can be left empty when already authenticated to the correct subscription."
  type        = string
  default     = ""
}

variable "location" {
  description = "Azure region for the deployment."
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of the resource group that will host the AKS environment."
  type        = string
  default     = "rg-aks-prod"
}

variable "cluster_name" {
  description = "Name of the AKS cluster."
  type        = string
  default     = "aks-prod"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "prod"
}

variable "owner" {
  description = "Owner or team name for tagging and governance."
  type        = string
  default     = "platform"
}

variable "tags" {
  description = "Additional Azure tags applied across resources."
  type        = map(string)
  default     = {}
}

variable "vnet_address_space" {
  description = "CIDR block for the AKS VNet."
  type        = list(string)
  default     = ["10.10.0.0/16"]
}

variable "subnet_address_prefixes" {
  description = "CIDR blocks for the AKS subnet."
  type        = list(string)
  default     = ["10.10.1.0/24"]
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster."
  type        = string
  default     = "1.29.7"
}

variable "dns_prefix" {
  description = "DNS prefix used for the AKS API server endpoint."
  type        = string
  default     = "aks-prod"
}

variable "private_cluster_enabled" {
  description = "Set to true to deploy a private AKS cluster."
  type        = bool
  default     = false
}

variable "authorized_ip_ranges" {
  description = "List of source IP ranges allowed to access the AKS API server. Use an empty list for public access."
  type        = list(string)
  default     = []
}

variable "ssh_public_key" {
  description = "Public SSH key used for Linux node administrators."
  type        = string
}

variable "system_node_pool_name" {
  description = "Name of the system node pool."
  type        = string
  default     = "system"
}

variable "system_node_count" {
  description = "Number of initial nodes in the system node pool."
  type        = number
  default     = 2
}

variable "system_node_vm_size" {
  description = "VM size for system nodes."
  type        = string
  default     = "Standard_DS2_v2"
}

variable "user_node_pool_name" {
  description = "Name of the user workload node pool."
  type        = string
  default     = "user"
}

variable "user_node_count" {
  description = "Initial size of the user node pool."
  type        = number
  default     = 2
}

variable "user_node_vm_size" {
  description = "VM size for workload nodes."
  type        = string
  default     = "Standard_DS3_v2"
}

variable "node_min_count" {
  description = "Minimum node count for autoscaling of the user pool."
  type        = number
  default     = 1
}

variable "node_max_count" {
  description = "Maximum node count for autoscaling of the user pool."
  type        = number
  default     = 5
}

variable "enable_user_pool_autoscaling" {
  description = "Whether autoscaling is enabled on the user node pool."
  type        = bool
  default     = true
}

variable "node_os_disk_size_gb" {
  description = "OS disk size for AKS nodes."
  type        = number
  default     = 128
}
