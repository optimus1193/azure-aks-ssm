provider "azurerm" {
  subscription_id     = local.s.subscription_id
  storage_use_azuread = true
  features {}
}

# The cluster already exists (01-cluster), so providers get real values at plan time.
# This removes the time_sleep/data-source race of configuring providers in the same apply.
# Names come from the same config.yaml and naming rules as 01-cluster, so no remote state is needed.
data "azurerm_kubernetes_cluster" "this" {
  name                = local.s.cluster_name
  resource_group_name = local.s.resource_group_name
}

locals {
  kube_host = data.azurerm_kubernetes_cluster.this.kube_config[0].host
  kube_ca   = base64decode(data.azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate)

  # kubelogin replaces `aws eks get-token`. 6dae42f8-... is the fixed AKS AAD server application ID.
  # login modes: azurecli (laptop/bastion, or after azure/login in the pipeline), workloadidentity, msi, spn
  kubelogin_args = concat(
    ["get-token", "--login", var.kubelogin_login_mode, "--server-id", "6dae42f8-4368-4678-94ff-3960e28e3630"],
    var.kubelogin_extra_args,
  )
}

provider "kubernetes" {
  host                   = local.kube_host
  cluster_ca_certificate = local.kube_ca
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "kubelogin"
    args        = local.kubelogin_args
  }
}

provider "helm" {
  kubernetes = {
    host                   = local.kube_host
    cluster_ca_certificate = local.kube_ca
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "kubelogin"
      args        = local.kubelogin_args
    }
  }
}

provider "kubectl" {
  host                   = local.kube_host
  cluster_ca_certificate = local.kube_ca
  load_config_file       = false
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "kubelogin"
    args        = local.kubelogin_args
  }
}
