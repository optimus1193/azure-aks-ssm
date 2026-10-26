variable "name" {
  description = "Resource name prefix for the monitoring resources."
  type        = string
}

variable "location" {
  description = "Azure region for the monitoring resources."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name that hosts the monitoring resources."
  type        = string
}

variable "tags" {
  description = "Tags for monitoring resources."
  type        = map(string)
  default     = {}
}
