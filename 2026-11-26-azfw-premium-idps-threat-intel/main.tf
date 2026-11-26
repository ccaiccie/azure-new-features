# ------------------------------------------------------------------------------
# Part 1: Hub VNet, AzureFirewallSubnet, Public IP & Log Analytics Workspace
# ------------------------------------------------------------------------------

resource "azurerm_resource_group" "lab" {
  name     = "rg-${var.prefix}-lab"
  location = var.location
}

resource "azurerm_virtual_network" "hub" {
  name                = "${var.prefix}-hub-vnet"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.95.0.0/16"]
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet" # Required exact subnet name
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.95.1.0/26"]
}

resource "azurerm_public_ip" "fw" {
  name                = "${var.prefix}-fw-pip"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_log_analytics_workspace" "fw" {
  name                = "${var.prefix}-fw-law"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# ------------------------------------------------------------------------------
# Part 2: Azure Firewall Premium Policy (IDPS + Threat Intel) & Firewall
# ------------------------------------------------------------------------------

resource "azurerm_firewall_policy" "premium" {
  name                     = "${var.prefix}-premium-policy"
  resource_group_name      = azurerm_resource_group.lab.name
  location                 = azurerm_resource_group.lab.location
  sku                      = "Premium"
  threat_intelligence_mode = var.threat_intel_mode

  threat_intelligence_allowlist {
    ip_addresses = ["203.0.113.0/24"] # Example RFC 5737 allowlist CIDR
  }

  intrusion_detection {
    mode           = var.idps_mode
    private_ranges = var.idps_private_ranges

    dynamic "signature_overrides" {
      for_each = var.idps_signature_overrides
      content {
        id    = signature_overrides.key
        state = signature_overrides.value
      }
    }
  }
}

# Sample application rule allowing Microsoft's official Threat Intel test FQDN
resource "azurerm_firewall_policy_rule_collection_group" "lab_rules" {
  name               = "${var.prefix}-rcg"
  firewall_policy_id = azurerm_firewall_policy.premium.id
  priority           = 200

  application_rule_collection {
    name     = "AllowThreatIntelTestFqdn"
    priority = 200
    action   = "Allow"

    rule {
      name = "AllowMicrosoftTestMaliciousDomain"
      protocols {
        type = "Http"
        port = 80
      }
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["10.95.0.0/16"]
      destination_fqdns = ["testmaliciousdomain.eastus.cloudapp.azure.com"]
    }
  }
}

resource "azurerm_firewall" "premium" {
  name                = "${var.prefix}-fw-premium"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Premium"
  firewall_policy_id  = azurerm_firewall_policy.premium.id

  ip_configuration {
    name                 = "fw-ipconfig"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.fw.id
  }
}

# Resource-specific Diagnostic Settings -> AZFWIdpsSignature & AZFWThreatIntel
resource "azurerm_monitor_diagnostic_setting" "fw_logs" {
  name                           = "${var.prefix}-fw-diag"
  target_resource_id             = azurerm_firewall.premium.id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.fw.id
  log_analytics_destination_type = "Dedicated"

  enabled_log { category = "AZFWIdpsSignature" }
  enabled_log { category = "AZFWThreatIntel" }
  enabled_log { category = "AZFWNetworkRule" }
  enabled_log { category = "AZFWApplicationRule" }
}
