############################################
# Customer-managed key for etcd secret encryption
# (replaces aws_kms_key + encryption_config)
############################################

resource "random_id" "key_vault_suffix" {
  count       = var.enable_kms_etcd_encryption ? 1 : 0
  byte_length = 3
}

locals {
  # Key Vault names are global, 3-24 chars, alphanumerics only here to avoid consecutive hyphens
  kms_key_vault_name = var.enable_kms_etcd_encryption ? "kv${substr(replace(trimprefix(var.cluster_name, "aks-"), "-", ""), 0, 16)}${random_id.key_vault_suffix[0].hex}" : null
  kms_private        = var.kms_key_vault_network_access == "Private"
}

resource "azurerm_key_vault" "kms" {
  count                         = var.enable_kms_etcd_encryption ? 1 : 0
  name                          = local.kms_key_vault_name
  location                      = var.location
  resource_group_name           = local.resource_group_name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  enable_rbac_authorization     = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 90
  public_network_access_enabled = !local.kms_private

  network_acls {
    bypass         = "AzureServices"
    default_action = local.kms_private ? "Deny" : "Allow"
  }

  tags = local.tags
}

resource "azurerm_private_endpoint" "kms" {
  count               = var.enable_kms_etcd_encryption && var.kms_private_endpoint != null ? 1 : 0
  name                = "pe-${local.kms_key_vault_name}"
  location            = var.location
  resource_group_name = local.resource_group_name
  subnet_id           = var.kms_private_endpoint.subnet_id

  private_service_connection {
    name                           = "psc-${local.kms_key_vault_name}"
    private_connection_resource_id = azurerm_key_vault.kms[0].id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  dynamic "private_dns_zone_group" {
    for_each = var.kms_private_endpoint.private_dns_zone_id != null ? [1] : []
    content {
      name                 = "default"
      private_dns_zone_ids = [var.kms_private_endpoint.private_dns_zone_id]
    }
  }

  tags = local.tags
}

# Terraform runner manages the key
resource "azurerm_role_assignment" "kms_deployer" {
  count                = var.enable_kms_etcd_encryption ? 1 : 0
  scope                = azurerm_key_vault.kms[0].id
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Cluster uses the key; private key vaults also need Key Vault Contributor so AKS can wire up private link
resource "azurerm_role_assignment" "kms_control_plane" {
  for_each             = var.enable_kms_etcd_encryption ? toset(concat(["Key Vault Crypto User"], local.kms_private ? ["Key Vault Contributor"] : [])) : toset([])
  scope                = azurerm_key_vault.kms[0].id
  role_definition_name = each.value
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
  principal_type       = "ServicePrincipal"
}

# Data-plane RBAC takes time to propagate before the key can be created
resource "time_sleep" "kms_rbac_propagation" {
  count           = var.enable_kms_etcd_encryption ? 1 : 0
  create_duration = "60s"
  depends_on      = [azurerm_role_assignment.kms_deployer, azurerm_private_endpoint.kms]
}

resource "azurerm_key_vault_key" "kms" {
  count        = var.enable_kms_etcd_encryption ? 1 : 0
  name         = "etcd-kms-${var.cluster_name}"
  key_vault_id = azurerm_key_vault.kms[0].id
  key_type     = "RSA"
  key_size     = 2048
  key_opts     = ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"]
  tags         = local.tags

  depends_on = [time_sleep.kms_rbac_propagation]
}
