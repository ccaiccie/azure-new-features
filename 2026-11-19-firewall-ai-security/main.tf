data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_user_assigned_identity" "fw_policy" {
  name                = "${var.name_prefix}-fwpolicy-id"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = var.tags
}

resource "azurerm_virtual_network" "hub" {
  name                = "${var.name_prefix}-hub"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = [var.hub_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.hub_firewall_subnet_cidr]
}

resource "azurerm_virtual_network" "spoke" {
  name                = "${var.name_prefix}-spoke"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = [var.spoke_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "workload" {
  name                 = "workload"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.spoke_workload_subnet_cidr]
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "${var.name_prefix}-spoke-to-hub"
  resource_group_name          = azurerm_resource_group.lab.name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = "${var.name_prefix}-hub-to-spoke"
  resource_group_name          = azurerm_resource_group.lab.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_public_ip" "fw" {
  name                = "${var.name_prefix}-fw-pip"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_log_analytics_workspace" "lab" {
  name                = "${var.name_prefix}-law"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_key_vault" "lab" {
  name                       = "${var.name_prefix}-${substr(data.azurerm_client_config.current.subscription_id, 0, 6)}-kv"
  location                   = azurerm_resource_group.lab.location
  resource_group_name        = azurerm_resource_group.lab.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  rbac_authorization_enabled = false
  tags                       = var.tags

  # Azure Firewall Premium is a Key Vault trusted service and can use this bypass.
  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }
}

resource "azurerm_key_vault_access_policy" "deployer" {
  key_vault_id = azurerm_key_vault.lab.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = ["Get", "List", "Set", "Delete", "Purge"]
}

resource "azurerm_key_vault_access_policy" "fw_policy" {
  key_vault_id = azurerm_key_vault.lab.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.fw_policy.principal_id

  secret_permissions = ["Get", "List"]
}

resource "azurerm_key_vault_secret" "intermediate_ca" {
  name         = "interCA"
  value        = filebase64(var.intermediate_ca_pfx_path)
  key_vault_id = azurerm_key_vault.lab.id
  content_type = "application/x-pkcs12"
  tags         = var.tags

  depends_on = [
    azurerm_key_vault_access_policy.deployer,
    azurerm_key_vault_access_policy.fw_policy
  ]
}

resource "azurerm_firewall_policy" "lab" {
  name                     = "${var.name_prefix}-fwpolicy"
  location                 = azurerm_resource_group.lab.location
  resource_group_name      = azurerm_resource_group.lab.name
  sku                      = "Premium"
  threat_intelligence_mode = "Alert"
  tags                     = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.fw_policy.id]
  }

  tls_certificate {
    name                = "AzureFirewallInspectionIntermediateCA"
    key_vault_secret_id = azurerm_key_vault_secret.intermediate_ca.id
  }

  intrusion_detection {
    mode = var.idps_mode
  }

  # The current azurerm provider has no argument for the AI Security add-on
  # (public preview). Microsoft documents that add-on as portal-only during
  # the preview: Terraform, Azure CLI, Azure PowerShell, and the REST API are
  # not supported for that configuration yet. Enable it in the portal after
  # apply; see the README.
}

resource "azurerm_firewall_policy_rule_collection_group" "lab" {
  name               = "${var.name_prefix}-rcg"
  firewall_policy_id = azurerm_firewall_policy.lab.id
  priority           = 200

  # Intentionally no broad network allow. Azure Firewall evaluates network
  # rules before application rules; a matching network allow would skip TLS
  # inspection and every AI Security profile attached to the HTTPS rule.

  application_rule_collection {
    name     = "inspected-https"
    priority = 200
    action   = "Allow"

    rule {
      name              = "https-with-tls-inspection"
      source_addresses  = [var.spoke_cidr]
      destination_fqdns = var.inspected_destination_fqdns
      terminate_tls     = true

      protocols {
        type = "Https"
        port = 443
      }
    }
  }
}

resource "azurerm_firewall" "lab" {
  name                = "${var.name_prefix}-azfw"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Premium"
  firewall_policy_id  = azurerm_firewall_policy.lab.id
  threat_intel_mode   = "Alert"
  tags                = var.tags

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.fw.id
  }

  depends_on = [azurerm_firewall_policy_rule_collection_group.lab]
}

resource "azurerm_route_table" "spoke" {
  name                = "${var.name_prefix}-spoke-rt"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = var.tags

  route {
    name                   = "default-to-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.lab.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "workload" {
  subnet_id      = azurerm_subnet.workload.id
  route_table_id = azurerm_route_table.spoke.id
}

resource "azurerm_monitor_diagnostic_setting" "fw" {
  name                       = "${var.name_prefix}-fw-diag"
  target_resource_id         = azurerm_firewall.lab.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.lab.id

  enabled_log { category = "AZFWApplicationRule" }
  enabled_log { category = "AZFWApplicationRuleAggregation" }
  enabled_log { category = "AZFWNetworkRule" }
  enabled_log { category = "AZFWNetworkRuleAggregation" }
  enabled_log { category = "AZFWIdpsSignature" }
  enabled_log { category = "AZFWThreatIntel" }
  enabled_log { category = "AZFWFqdnResolveFailure" }

  enabled_metric { category = "AllMetrics" }
}
