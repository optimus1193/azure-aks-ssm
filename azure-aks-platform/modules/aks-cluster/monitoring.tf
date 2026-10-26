############################################
# Log Analytics (replaces CloudWatch log groups + the retention null_resource;
# retention is a native workspace property here)
############################################

resource "azurerm_log_analytics_workspace" "this" {
  count               = var.log_analytics_workspace_id == null ? 1 : 0
  name                = "log-${var.cluster_name}"
  location            = var.location
  resource_group_name = local.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_in_days
  daily_quota_gb      = var.log_daily_quota_gb
  tags                = local.tags
}

# Control plane logs (replaces enabled_cluster_log_types).
# Dedicated = resource-specific tables, cheaper and faster to query than AzureDiagnostics.
resource "azurerm_monitor_diagnostic_setting" "control_plane" {
  count                          = length(var.control_plane_log_categories) > 0 ? 1 : 0
  name                           = "diag-${var.cluster_name}"
  target_resource_id             = azurerm_kubernetes_cluster.this.id
  log_analytics_workspace_id     = local.log_analytics_workspace_id
  log_analytics_destination_type = "Dedicated"

  dynamic "enabled_log" {
    for_each = toset(var.control_plane_log_categories)
    content {
      category = enabled_log.value
    }
  }
}

############################################
# Container Insights (replaces amazon-cloudwatch-observability + fluent-bit)
############################################

resource "azurerm_monitor_data_collection_rule" "container_insights" {
  count               = var.enable_container_insights ? 1 : 0
  name                = "MSCI-${var.location}-${var.cluster_name}"
  location            = var.location
  resource_group_name = local.resource_group_name
  kind                = "Linux"

  destinations {
    log_analytics {
      workspace_resource_id = local.log_analytics_workspace_id
      name                  = "ciworkspace"
    }
  }

  data_flow {
    streams      = var.container_insights.streams
    destinations = ["ciworkspace"]
  }

  data_sources {
    extension {
      name           = "ContainerInsightsExtension"
      extension_name = "ContainerInsights"
      streams        = var.container_insights.streams
      extension_json = jsonencode({
        dataCollectionSettings = {
          interval               = var.container_insights.interval
          namespaceFilteringMode = "Exclude"
          namespaces             = var.container_insights.excluded_namespaces
          enableContainerLogV2   = true
        }
      })
    }
  }

  tags = local.tags
}

resource "azurerm_monitor_data_collection_rule_association" "container_insights" {
  count                   = var.enable_container_insights ? 1 : 0
  name                    = "ContainerInsightsExtension"
  target_resource_id      = azurerm_kubernetes_cluster.this.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.container_insights[0].id
}

############################################
# Managed Prometheus (replaces enhanced container insights metrics)
############################################

resource "azurerm_monitor_workspace" "prometheus" {
  count               = var.enable_managed_prometheus ? 1 : 0
  name                = "amw-${var.cluster_name}"
  location            = var.location
  resource_group_name = local.resource_group_name
  tags                = local.tags
}

resource "azurerm_monitor_data_collection_endpoint" "prometheus" {
  count               = var.enable_managed_prometheus ? 1 : 0
  name                = "MSProm-${var.location}-${var.cluster_name}"
  location            = var.location
  resource_group_name = local.resource_group_name
  kind                = "Linux"
  tags                = local.tags
}

resource "azurerm_monitor_data_collection_rule" "prometheus" {
  count                       = var.enable_managed_prometheus ? 1 : 0
  name                        = "MSProm-${var.location}-${var.cluster_name}"
  location                    = var.location
  resource_group_name         = local.resource_group_name
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.prometheus[0].id
  kind                        = "Linux"

  destinations {
    monitor_account {
      monitor_account_id = azurerm_monitor_workspace.prometheus[0].id
      name               = "MonitoringAccount1"
    }
  }

  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = ["MonitoringAccount1"]
  }

  data_sources {
    prometheus_forwarder {
      streams = ["Microsoft-PrometheusMetrics"]
      name    = "PrometheusDataSource"
    }
  }

  tags = local.tags
}

resource "azurerm_monitor_data_collection_rule_association" "prometheus" {
  count                   = var.enable_managed_prometheus ? 1 : 0
  name                    = "MSProm-${var.location}-${var.cluster_name}"
  target_resource_id      = azurerm_kubernetes_cluster.this.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.prometheus[0].id
}

resource "azurerm_monitor_data_collection_rule_association" "prometheus_endpoint" {
  count                       = var.enable_managed_prometheus ? 1 : 0
  target_resource_id          = azurerm_kubernetes_cluster.this.id
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.prometheus[0].id
}
