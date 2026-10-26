variable "config_file" {
  type        = string
  description = "Absolute path to the customer's environments/<env>/config.yaml"
}

# Runner settings, owned by the hub pipeline rather than the customer config
variable "kubelogin_login_mode" {
  type        = string
  description = "kubelogin --login mode: azurecli, workloadidentity, msi or spn"
  default     = "azurecli"
}

variable "kubelogin_extra_args" {
  type        = list(string)
  description = "Extra kubelogin args, e.g. [\"--client-id\", \"<agent-msi-client-id>\"] for --login msi"
  default     = []
}
