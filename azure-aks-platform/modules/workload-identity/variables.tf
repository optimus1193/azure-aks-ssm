variable "name" {
  type        = string
  description = "Name of the user-assigned managed identity"
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "oidc_issuer_url" {
  type        = string
  description = "AKS OIDC issuer URL"
}

variable "namespace" {
  type = string
}

variable "service_account" {
  type = string
}

variable "role_assignments" {
  type = map(object({
    scope                = string
    role_definition_name = string
  }))
  description = "Azure role assignments for the identity. Keys must be static strings."
  default     = {}
}

variable "resource_tags" {
  type    = map(string)
  default = {}
}
