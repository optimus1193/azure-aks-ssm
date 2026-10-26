# terraform -chdir=modules/config init && terraform -chdir=modules/config test

run "full_config" {
  command = plan
  variables {
    config_file = "tests/fixtures/valid.yaml"
  }

  assert {
    condition     = output.settings.cluster_name == "aks-myapp-prod" && output.settings.resource_group_name == "rg-aks-myapp-prod"
    error_message = "Names must follow aks-<name>-<env> / rg-aks-<name>-<env>"
  }
  assert {
    condition     = output.settings.tags.Environment == "PROD" && output.settings.tags.Managed_By == "azure-aks-platform" && output.settings.tags.Cost_Center == "CC123"
    error_message = "Mandatory tags must be merged over customer tags"
  }
  assert {
    condition     = replace(output.settings.rbac_manifests_dir, "\\", "/") == "tests/fixtures/rbac"
    error_message = "RBAC manifests are read from rbac/ next to config.yaml"
  }
}

run "defaults_when_features_omitted" {
  command = plan
  variables {
    config_file = "tests/fixtures/minimal.yaml"
  }

  assert {
    condition     = output.settings.features.kyverno && !output.settings.features.keda && !output.settings.features.delete_lock
    error_message = "Hub feature defaults must apply (delete_lock is on only in prod)"
  }
}

run "core_offerings_cannot_be_toggled" {
  command = plan
  variables {
    config_file = "tests/fixtures/core-toggled.yaml"
  }
  expect_failures = [output.settings]
}

run "typos_and_missing_keys_fail" {
  command = plan
  variables {
    config_file = "tests/fixtures/invalid.yaml"
  }
  expect_failures = [output.settings]
}
