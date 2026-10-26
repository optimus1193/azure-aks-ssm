# Plans the stack against sample customer configs. The aks-cluster module is overridden (its
# resources need real Azure IDs), but its inputs are still type-checked and validated, which is
# what proves the config.yaml -> module mapping.
# Needs Terraform >= 1.11.
# terraform -chdir=stacks/01-cluster init -backend=false && terraform -chdir=stacks/01-cluster test

mock_provider "azurerm" {}
mock_provider "random" {}
mock_provider "time" {}

override_module {
  target = module.aks_cluster
  outputs = {
    cluster_name               = "aks-myapp-prod"
    resource_group_name        = "rg-aks-myapp-prod"
    kubernetes_version         = "1.35.0"
    private_fqdn               = "aks-myapp-prod.privatelink.southafricanorth.azmk8s.io"
    oidc_issuer_url            = "https://oidc.example.com/"
    log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-aks-myapp-prod/providers/Microsoft.OperationalInsights/workspaces/log-aks-myapp-prod"
  }
}

run "sample_customer_config" {
  command = plan
  variables {
    config_file = "../../modules/config/tests/fixtures/valid.yaml"
  }

  assert {
    condition     = output.features.node_auto_provisioning && !output.features.keda && output.features.delete_lock
    error_message = "Feature toggles from config.yaml must reach the stack"
  }
}

run "minimal_config_uses_module_defaults" {
  command = plan
  variables {
    config_file = "../../modules/config/tests/fixtures/minimal.yaml"
  }
}

