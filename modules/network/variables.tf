variable "name" {
  description = "A name prefix used in resource naming."
  type        = string
}

variable "location" {
  description = "Azure region for the VNet resources."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name that hosts the network resources."
  type        = string
}

variable "vnet_address_space" {
  description = "IP address space for the virtual network."
  type        = list(string)
}

variable "subnet_address_prefixes" {
  description = "Address prefixes for the AKS subnet."
  type        = list(string)
}

variable "tags" {
  description = "Tags for network resources."
  type        = map(string)
  default     = {}
}
