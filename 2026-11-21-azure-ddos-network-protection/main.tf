resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
}

# 1. Azure DDoS Network Protection Plan (covers up to 100 Public IPs across VNets in the tenant)
resource "azurerm_network_ddos_protection_plan" "plan" {
  name                = "${var.prefix}-plan"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
}

# 2. Hub Virtual Network associated with the DDoS Protection Plan
resource "azurerm_virtual_network" "hub" {
  name                = "${var.prefix}-hub-vnet"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.10.0.0/16"]

  ddos_protection_plan {
    id     = azurerm_network_ddos_protection_plan.plan.id
    enable = true
  }
}

resource "azurerm_subnet" "appgw" {
  name                 = "snet-appgw"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.10.1.0/24"]
}

# 3. Standard Public IP (automatically protected once associated with a resource in the protected VNet)
resource "azurerm_public_ip" "edge" {
  name                = "${var.prefix}-edge-pip"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# 4. Log Analytics Workspace + Diagnostic Settings for DDoS Telemetry
resource "azurerm_log_analytics_workspace" "sec" {
  name                = "${var.prefix}-law"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_monitor_diagnostic_setting" "pip_ddos_logs" {
  name                       = "ddos-telemetry-to-law"
  target_resource_id         = azurerm_public_ip.edge.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.sec.id

  enabled_log {
    category = "DDoSProtectionNotifications"
  }

  enabled_log {
    category = "DDoSMitigationFlowLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# 5. Azure Monitor Metric Alert on IfUnderDDoSAttack
resource "azurerm_monitor_metric_alert" "under_attack" {
  name                = "${var.prefix}-under-ddos-attack"
  resource_group_name = azurerm_resource_group.lab.name
  scopes              = [azurerm_public_ip.edge.id]
  description         = "Alerts when the protected Public IP is under an active DDoS attack."
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Network/publicIPAddresses"
    metric_name      = "IfUnderDDoSAttack"
    aggregation      = "Maximum"
    operator         = "GreaterThan"
    threshold        = 0
  }
}
