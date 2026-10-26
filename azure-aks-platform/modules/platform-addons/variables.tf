############################################
# Cluster context
############################################

variable "cluster_name" {
  type = string
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for identities created by this module"
}

variable "location" {
  type = string
}

variable "oidc_issuer_url" {
  type = string
}

variable "resource_tags" {
  type    = map(string)
  default = {}
  nullable    = false
}

variable "platform_key_vault_id" {
  type        = string
  description = "Key Vault holding platform secrets (ArgoCD admin password, git credentials). Replaces Secrets Manager."
  nullable    = false
}

############################################
# Helm sources
############################################

variable "helm_repository_override" {
  type        = string
  description = "Pull every chart from one mirror instead of upstream, e.g. oci://myacr.azurecr.io/helm (equivalent of the private ECR registry)"
  default     = null
}

variable "chart_versions" {
  type        = map(string)
  description = "Override individual chart versions. Keys: argocd, traefik, kyverno, policy_reporter, reloader."
  default     = {}
  nullable    = false
}

############################################
# Ingress (Traefik on an internal Azure Load Balancer)
# Core offering: always installed, there is no enable_traefik toggle.
############################################

variable "traefik" {
  type = object({
    replicas            = optional(number, 3)
    internal            = optional(bool, true)
    lb_subnet_name      = optional(string) # place the internal LB in a specific subnet of the cluster VNet
    lb_static_ip        = optional(string)
    default_ingress     = optional(bool, true)
  })
  default = {}
  nullable    = false
}

variable "ingress_class_name" {
  type        = string
  description = "IngressClass used by platform UIs"
  default     = "traefik"
  nullable    = false
}

############################################
# ArgoCD
# Core offering: always installed, there is no enable_argocd toggle.
############################################

variable "argocd" {
  type = object({
    domain                      = string
    ha_enabled                  = optional(bool, true)
    admin_password_secret_name  = optional(string, "argocd-admin-password")
    git_credentials_secret_name = optional(string) # Key Vault secret with JSON {"username": "...", "password": "..."}
    ingress_tls_secret_name     = optional(string)
    repositories = optional(map(object({
      url     = string
      project = optional(string, "default")
      type    = optional(string, "git")
    })), {})
    acr_ids = optional(list(string), []) # repo-server gets AcrPull via workload identity for OCI helm charts
  })
  nullable = false
}

############################################
# Policy & ops
# Optional offerings: customers toggle these.
############################################

variable "enable_kyverno" {
  type    = bool
  default = true
  nullable    = false
}

variable "kyverno_dashboard_domain" {
  type        = string
  description = "Hostname for the Policy Reporter UI. null = no ingress."
  default     = null
}

variable "enable_reloader" {
  type    = bool
  default = true
  nullable    = false
}

variable "rbac_manifests_dir" {
  type        = string
  description = "Directory of *.yaml / *.yml RBAC manifests to apply (Roles, RoleBindings to Entra group object IDs). null = skip."
  default     = null
}
