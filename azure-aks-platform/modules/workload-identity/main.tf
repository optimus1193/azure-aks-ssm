# Azure equivalent of the irsa module: a managed identity that a single
# Kubernetes service account can federate into, plus its Azure role assignments.

resource "azurerm_user_assigned_identity" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.resource_tags
}

resource "azurerm_federated_identity_credential" "this" {
  name                = "${var.namespace}-${var.service_account}"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.this.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.oidc_issuer_url
  subject             = "system:serviceaccount:${var.namespace}:${var.service_account}"
}

resource "azurerm_role_assignment" "this" {
  for_each             = var.role_assignments
  scope                = each.value.scope
  role_definition_name = each.value.role_definition_name
  principal_id         = azurerm_user_assigned_identity.this.principal_id
  principal_type       = "ServicePrincipal"
}
