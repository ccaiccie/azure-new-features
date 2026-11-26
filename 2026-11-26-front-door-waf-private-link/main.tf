resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
}

# 1. Log Analytics Workspace for Front Door WAF, Access, and Health Probe logs
resource "azurerm_log_analytics_workspace" "lab" {
  name                = "law-${var.project_prefix}-${random_string.suffix.result}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
}

# 2. Private Origin: Linux App Service with public network access disabled
resource "azurerm_service_plan" "origin" {
  name                = "asp-${var.project_prefix}-${random_string.suffix.result}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  os_type             = "Linux"
  sku_name            = var.app_service_sku
}

resource "azurerm_linux_web_app" "origin" {
  name                          = "app-${var.project_prefix}-${random_string.suffix.result}"
  location                      = azurerm_resource_group.lab.location
  resource_group_name           = azurerm_resource_group.lab.name
  service_plan_id               = azurerm_service_plan.origin.id
  https_only                    = true
  public_network_access_enabled = false

  site_config {
    always_on = true
    application_stack {
      node_version = "20-lts"
    }
  }
}

# 3. Azure Front Door Premium Profile (required for Managed WAF rules + Private Link origins)
resource "azurerm_cdn_frontdoor_profile" "lab" {
  name                = "afd-${var.project_prefix}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.lab.name
  sku_name            = "Premium_AzureFrontDoor"
}

resource "azurerm_cdn_frontdoor_endpoint" "lab" {
  name                     = "ep-${var.project_prefix}-${random_string.suffix.result}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.lab.id
}

resource "azurerm_cdn_frontdoor_origin_group" "private_app" {
  name                     = "og-private-webapp"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.lab.id

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }

  health_probe {
    protocol            = "Https"
    path                = "/"
    request_type        = "HEAD"
    interval_in_seconds = 30
  }
}

resource "azurerm_cdn_frontdoor_origin" "private_app" {
  name                           = "origin-private-webapp"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.private_app.id
  enabled                        = true
  certificate_name_check_enabled = true

  host_name          = azurerm_linux_web_app.origin.default_hostname
  origin_host_header = azurerm_linux_web_app.origin.default_hostname
  http_port          = 80
  https_port         = 443
  priority           = 1
  weight             = 1000

  private_link {
    request_message        = "Approve Front Door Premium Private Link to lab Web App"
    target_type            = "sites"
    location               = azurerm_resource_group.lab.location
    private_link_target_id = azurerm_linux_web_app.origin.id
  }
}

resource "azurerm_cdn_frontdoor_route" "lab" {
  name                          = "route-private-webapp"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.lab.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.private_app.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.private_app.id]

  supported_protocols    = ["Http", "Https"]
  patterns_to_match      = ["/*"]
  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true
  link_to_default_domain = true
}

# 4. Front Door WAF Policy: Custom Rule + Managed Default Rule Set + Bot Manager
resource "azurerm_cdn_frontdoor_firewall_policy" "lab" {
  name                              = "waf${var.project_prefix}${random_string.suffix.result}"
  resource_group_name               = azurerm_resource_group.lab.name
  sku_name                          = azurerm_cdn_frontdoor_profile.lab.sku_name
  enabled                           = true
  mode                              = var.waf_mode
  custom_block_response_status_code = 403
  custom_block_response_body        = base64encode("Blocked by Azure Front Door WAF Lab Policy")

  # Custom rule evaluated BEFORE managed rule sets
  custom_rule {
    name     = "BlockLabHeader"
    enabled  = true
    priority = 100
    type     = "MatchRule"
    action   = "Block"

    match_condition {
      match_variable     = "RequestHeader"
      selector           = "X-Lab-Test"
      operator           = "Equal"
      negation_condition = false
      match_values       = [var.blocked_test_header_value]
      transforms         = ["Lowercase", "Trim"]
    }
  }

  # Azure-managed Default Rule Set (DRS 2.1 with anomaly scoring)
  managed_rule {
    type    = "Microsoft_DefaultRuleSet"
    version = "2.1"
    action  = "Block"
  }

  # Azure-managed Bot Manager 1.1 (Premium)
  managed_rule {
    type    = "Microsoft_BotManagerRuleSet"
    version = "1.1"
    action  = "Block"
  }
}

# Attach WAF policy to the Front Door endpoint domain
resource "azurerm_cdn_frontdoor_security_policy" "lab" {
  name                     = "secpol-waf-lab"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.lab.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.lab.id

      association {
        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_endpoint.lab.id
        }
        patterns_to_match = ["/*"]
      }
    }
  }
}

# 5. Diagnostic Settings for Front Door WAF, Access, and Health Probe logs
resource "azurerm_monitor_diagnostic_setting" "afd" {
  name                       = "diag-afd-waf-logs"
  target_resource_id         = azurerm_cdn_frontdoor_profile.lab.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.lab.id

  enabled_log {
    category = "FrontDoorAccessLog"
  }

  enabled_log {
    category = "FrontDoorWebApplicationFirewallLog"
  }

  enabled_log {
    category = "FrontDoorHealthProbeLog"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
