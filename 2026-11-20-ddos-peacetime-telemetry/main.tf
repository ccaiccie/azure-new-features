resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Paid SKU. Review Azure DDoS Protection pricing before you apply, and destroy
# this lab when you finish. Peacetime telemetry requires a protected public IP.
resource "azurerm_network_ddos_protection_plan" "lab" {
  name                = "${var.name_prefix}-ddos-plan"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = var.tags
}

resource "azurerm_virtual_network" "lab" {
  name                = "${var.name_prefix}-vnet"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = [var.vnet_cidr]
  tags                = var.tags

  ddos_protection_plan {
    id     = azurerm_network_ddos_protection_plan.lab.id
    enable = true
  }
}

resource "azurerm_subnet" "lab" {
  name                 = "${var.name_prefix}-snet"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = [var.subnet_cidr]
}

resource "azurerm_public_ip" "front" {
  name                = "${var.name_prefix}-pip"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Associating the Standard public IP with a Standard Load Balancer frontend
# places the IP on a resource in the protected virtual network.
resource "azurerm_lb" "lab" {
  name                = "${var.name_prefix}-lb"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                 = "public"
    public_ip_address_id = azurerm_public_ip.front.id
  }
}

resource "azurerm_lb_backend_address_pool" "lab" {
  name            = "backend"
  loadbalancer_id = azurerm_lb.lab.id
}

resource "azurerm_log_analytics_workspace" "lab" {
  name                = "${var.name_prefix}-law"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# Viewing peacetime platform metrics does not require this workspace.
# The setting is here so you can export DDoS resource logs and supported metrics.
# DDoSMitigationReports is omitted: that category was retired starting mid-August 2026.
resource "azurerm_monitor_diagnostic_setting" "pip" {
  name                       = "${var.name_prefix}-pip-diag"
  target_resource_id         = azurerm_public_ip.front.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.lab.id

  enabled_log {
    category = "DDoSMitigationFlowLogs"
  }

  enabled_log {
    category = "DDoSProtectionNotifications"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_action_group" "lab" {
  name                = "${var.name_prefix}-ag"
  resource_group_name = azurerm_resource_group.lab.name
  short_name          = "ddoslab"
  tags                = var.tags

  dynamic "email_receiver" {
    for_each = var.alert_email == "" ? [] : [var.alert_email]
    content {
      name                    = "lab-email"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }
}

# Attack-status alert. This is the signal that an attack was reported.
resource "azurerm_monitor_metric_alert" "under_attack" {
  name                = "${var.name_prefix}-under-attack"
  resource_group_name = azurerm_resource_group.lab.name
  scopes              = [azurerm_public_ip.front.id]
  description         = "Fires when Under DDoS attack or not (IfUnderDDoSAttack) reports 1. With Maximum aggregation, a 1 can refer to any reported attack measurement in the lookback period."
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"
  enabled             = true
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Network/publicIPAddresses"
    metric_name      = "IfUnderDDoSAttack"
    aggregation      = "Maximum"
    operator         = "GreaterThanOrEqual"
    threshold        = 1
  }

  action {
    action_group_id = azurerm_monitor_action_group.lab.id
  }
}

# Traffic-condition alerts (peacetime telemetry preview). Thresholds are placeholders.
# These can fire while IfUnderDDoSAttack remains 0 and do not change mitigation.
resource "azurerm_monitor_metric_alert" "tcp_packets" {
  name                = "${var.name_prefix}-tcp-pps"
  resource_group_name = azurerm_resource_group.lab.name
  scopes              = [azurerm_public_ip.front.id]
  description         = "PLACEHOLDER traffic-condition alert on Inbound TCP packets DDoS (TCPPacketsInDDoS). Replace the threshold from a peacetime baseline. This does not change DDoS mitigation."
  severity            = 3
  frequency           = "PT1M"
  window_size         = "PT5M"
  enabled             = true
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Network/publicIPAddresses"
    metric_name      = "TCPPacketsInDDoS"
    aggregation      = "Maximum"
    operator         = "GreaterThan"
    threshold        = var.tcp_packets_alert_threshold_pps
  }

  action {
    action_group_id = azurerm_monitor_action_group.lab.id
  }
}

resource "azurerm_monitor_metric_alert" "syn_packets" {
  name                = "${var.name_prefix}-syn-pps"
  resource_group_name = azurerm_resource_group.lab.name
  scopes              = [azurerm_public_ip.front.id]
  description         = "PLACEHOLDER traffic-condition alert on Inbound SYN packets DDoS (SYNPacketsInDDoS). Replace the threshold from a peacetime baseline. This does not change DDoS mitigation."
  severity            = 3
  frequency           = "PT1M"
  window_size         = "PT5M"
  enabled             = true
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Network/publicIPAddresses"
    metric_name      = "SYNPacketsInDDoS"
    aggregation      = "Maximum"
    operator         = "GreaterThan"
    threshold        = var.syn_packets_alert_threshold_pps
  }

  action {
    action_group_id = azurerm_monitor_action_group.lab.id
  }
}

resource "azurerm_monitor_metric_alert" "inbound_packets" {
  name                = "${var.name_prefix}-inbound-pps"
  resource_group_name = azurerm_resource_group.lab.name
  scopes              = [azurerm_public_ip.front.id]
  description         = "PLACEHOLDER traffic-condition alert on Inbound packets DDoS (PacketsInDDoS). Replace the threshold from a peacetime baseline. This does not change DDoS mitigation."
  severity            = 3
  frequency           = "PT1M"
  window_size         = "PT5M"
  enabled             = true
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Network/publicIPAddresses"
    metric_name      = "PacketsInDDoS"
    aggregation      = "Maximum"
    operator         = "GreaterThan"
    threshold        = var.inbound_packets_alert_threshold_pps
  }

  action {
    action_group_id = azurerm_monitor_action_group.lab.id
  }
}
