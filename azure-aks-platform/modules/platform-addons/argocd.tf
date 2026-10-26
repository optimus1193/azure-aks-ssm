############################################
# Secrets from Key Vault (replaces Secrets Manager lookups)
############################################

data "azurerm_key_vault_secret" "argocd_admin_password" {
  name         = var.argocd.admin_password_secret_name
  key_vault_id = var.platform_key_vault_id
}

data "azurerm_key_vault_secret" "git_credentials" {
  count        = var.argocd.git_credentials_secret_name != null ? 1 : 0
  name         = var.argocd.git_credentials_secret_name
  key_vault_id = var.platform_key_vault_id
}

locals {
  argocd_ns       = "argocd"
  git_credentials = length(data.azurerm_key_vault_secret.git_credentials) > 0 ? jsondecode(data.azurerm_key_vault_secret.git_credentials[0].value) : null
  argocd_wi       = length(var.argocd.acr_ids) > 0
}

resource "bcrypt_hash" "argocd_admin" {
  cleartext = data.azurerm_key_vault_secret.argocd_admin_password.value
}

# Only changes when the password changes (the old timestamp() produced a diff on every plan)
resource "time_static" "argocd_admin_password" {
  triggers = {
    hash = bcrypt_hash.argocd_admin.id
  }
}

############################################
# Workload identity for repo-server (replaces irsa_argocd)
############################################

module "argocd_workload_identity" {
  source = "../workload-identity"
  count  = local.argocd_wi ? 1 : 0

  name                = "id-${var.cluster_name}-argocd-repo-server"
  location            = var.location
  resource_group_name = var.resource_group_name
  oidc_issuer_url     = var.oidc_issuer_url
  namespace           = local.argocd_ns
  service_account     = "argocd-repo-server"
  resource_tags       = var.resource_tags
  role_assignments = {
    for i, id in var.argocd.acr_ids : "acr-${i}" => {
      scope                = id
      role_definition_name = "AcrPull"
    }
  }
}

############################################
# Helm release
############################################

locals {
  argocd_replicas = var.argocd.ha_enabled ? 2 : 1

  argocd_values = {
    global = {
      domain = var.argocd.domain
    }
    configs = {
      params = {
        # TLS terminates at the ingress controller
        "server.insecure" = true
      }
      secret = {
        argocdServerAdminPassword      = bcrypt_hash.argocd_admin.id
        argocdServerAdminPasswordMtime = time_static.argocd_admin_password.rfc3339
      }
    }
    "redis-ha" = {
      enabled = var.argocd.ha_enabled
    }
    controller = {
      replicas = 1
    }
    server = {
      replicas = local.argocd_replicas
      ingress = {
        enabled          = true
        ingressClassName = var.ingress_class_name
        extraTls = var.argocd.ingress_tls_secret_name == null ? [] : [{
          hosts      = [var.argocd.domain]
          secretName = var.argocd.ingress_tls_secret_name
        }]
      }
    }
    repoServer = {
      replicas = local.argocd_replicas
      serviceAccount = {
        annotations = local.argocd_wi ? { "azure.workload.identity/client-id" = module.argocd_workload_identity[0].client_id } : {}
      }
      podLabels = local.argocd_wi ? { "azure.workload.identity/use" = "true" } : {}
    }
    applicationSet = {
      replicas = local.argocd_replicas
    }
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = local.argocd_ns
  create_namespace = true
  repository       = local.repositories.argocd
  chart            = "argo-cd"
  version          = local.chart_versions.argocd
  atomic           = true
  cleanup_on_fail  = true
  max_history      = 5
  timeout          = 900

  values = [yamlencode(local.argocd_values)]

  depends_on = [helm_release.traefik]
}

############################################
# Repository credentials (replaces github_repo_secret)
############################################

resource "kubernetes_secret_v1" "argocd_repository" {
  for_each = var.argocd.repositories

  metadata {
    name      = each.key
    namespace = local.argocd_ns
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    for k, v in {
      url      = each.value.url
      type     = each.value.type
      project  = each.value.project
      username = try(local.git_credentials.username, null)
      password = try(local.git_credentials.password, null)
    } : k => v if v != null
  }

  type = "Opaque"

  depends_on = [helm_release.argocd]
}
