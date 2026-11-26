resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Optional: Azure DDoS Network Protection Plan
# Defaults to NOT created (var.enable_network_protection = false).
# COST WARNING: A DDoS Network Protection plan incurs a fixed monthly fee (prorated hourly)
# until the plan resource itself is deleted, not merely disabled on a virtual network.
resource "azurerm_network_ddos_protection_plan" "optional" {
  count               = var.enable_network_protection ? 1 : 0
  name                = var.ddos_plan_name
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = var.tags
}

# Virtual Network demonstrating where a Network Protection plan attaches when enabled.
resource "azurerm_virtual_network" "lab" {
  name                = var.vnet_name
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = var.tags

  dynamic "ddos_protection_plan" {
    for_each = var.enable_network_protection ? [1] : []
    content {
      id     = azurerm_network_ddos_protection_plan.optional[0].id
      enable = true
    }
  }
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.10.1.0/24"]
}

# Default runnable path: Standard SKU Public IP with Azure DDoS IP Protection enabled.
# COST WARNING: Enabling DDoS IP Protection bills per protected public IP while active.
# Note: DDoS IP Protection is supported on Standard SKU public IPs only (not Basic SKU).
resource "azurerm_public_ip" "lab" {
  name                = var.public_ip_name
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"

  ddos_protection_mode = var.enable_network_protection ? "VirtualNetworkInherited" : (
    var.enable_ip_protection ? "Enabled" : "Disabled"
  )

  tags = var.tags
}

# Optional: Log Analytics workspace and diagnostic setting for peacetime validation of log routing.
resource "azurerm_log_analytics_workspace" "optional" {
  count               = var.enable_diagnostic_logging ? 1 : 0
  name                = "law-${var.resource_group_name}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "pip_ddos" {
  count                      = var.enable_diagnostic_logging ? 1 : 0
  name                       = "diag-ddos-pip"
  target_resource_id         = azurerm_public_ip.lab.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.optional[0].id

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
