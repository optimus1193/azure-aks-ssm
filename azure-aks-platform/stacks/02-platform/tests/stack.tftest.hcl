# Plans the stack against the sample customer config with mocked providers (no cluster access needed).
# terraform -chdir=stacks/02-platform init -backend=false && terraform -chdir=stacks/02-platform test

mock_provider "azurerm" {
  override_data {
    target = data.azurerm_kubernetes_cluster.this
    values = {
      name                = "aks-myapp-prod"
      resource_group_name = "rg-aks-myapp-prod"
      location            = "southafricanorth"
      oidc_issuer_url     = "https://oidc.example.com/"
      kube_config = [{
        host                   = "https://aks-myapp-prod.privatelink.southafricanorth.azmk8s.io:443"
        cluster_ca_certificate = "Y2E="
      }]
    }
  }
}
mock_provider "helm" {}
mock_provider "kubernetes" {}
mock_provider "kubectl" {}
mock_provider "time" {}
mock_provider "bcrypt" {}

override_data {
  target = module.platform_addons.data.azurerm_key_vault_secret.git_credentials
  values = {
    value = "{\"username\": \"git\", \"password\": \"secret\"}"
  }
}

run "sample_customer_config" {
  command = plan
  variables {
    config_file = "../../modules/config/tests/fixtures/valid.yaml"
  }

  assert {
    condition     = output.addons.traefik && output.addons.argocd && output.addons.kyverno
    error_message = "Core add-ons are always installed; optional ones follow features"
  }
  assert {
    condition     = length(module.node_provisioning) == 1
    error_message = "NodePools are created when node_auto_provisioning is on"
  }
  assert {
    condition     = output.rbac_manifests_applied == ["ClusterRole/_cluster/namespace-developer"]
    error_message = "RBAC manifests are read from rbac/ next to config.yaml"
  }
}

run "minimal_config_still_installs_core" {
  command = plan
  variables {
    config_file = "../../modules/config/tests/fixtures/minimal.yaml"
  }

  assert {
    condition     = output.addons.traefik && output.addons.argocd
    error_message = "Traefik and ArgoCD are installed even when the config does not mention them"
  }
}
