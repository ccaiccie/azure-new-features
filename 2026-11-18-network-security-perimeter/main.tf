# Azure network security perimeter around a storage account and a key vault,
# one profile with an inbound prefix rule and an outbound FQDN rule, and access logs.

data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
}

# ---------- PaaS members ----------

resource "azurerm_storage_account" "data" {
  name                     = "${var.name_prefix}st${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.lab.name
  location                 = azurerm_resource_group.lab.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  # Shared keys (SAS) are rejected for intra-perimeter and subscription-rule traffic: use Entra ID.
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
}

resource "azurerm_key_vault" "kv" {
  name                       = "${var.name_prefix}-kv-${random_string.suffix.result}"
  resource_group_name        = azurerm_resource_group.lab.name
  location                   = azurerm_resource_group.lab.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  purge_protection_enabled   = false
}

# Log destination for access logs. Keep it in the same perimeter as the members.
resource "azurerm_log_analytics_workspace" "logs" {
  name                = "${var.name_prefix}-law-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# ---------- Perimeter, profile and rules ----------

resource "azurerm_network_security_perimeter" "nsp" {
  name                = "${var.name_prefix}-nsp"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
}

resource "azurerm_network_security_perimeter_profile" "data" {
  name                          = "data-services"
  network_security_perimeter_id = azurerm_network_security_perimeter.nsp.id
}

# Inbound: address prefixes (subscription_ids and service_tags are the other inbound types).
resource "azurerm_network_security_perimeter_access_rule" "in_office" {
  name                                  = "allow-office-egress"
  network_security_perimeter_profile_id = azurerm_network_security_perimeter_profile.data.id
  direction                             = "Inbound"
  address_prefixes                      = var.allowed_inbound_prefixes
}

# Inbound: your own subscription (requests must use Entra ID, not SAS).
resource "azurerm_network_security_perimeter_access_rule" "in_subscription" {
  name                                  = "allow-own-subscription"
  network_security_perimeter_profile_id = azurerm_network_security_perimeter_profile.data.id
  direction                             = "Inbound"
  subscription_ids                      = ["/subscriptions/${data.azurerm_client_config.current.subscription_id}"]
}

# Outbound: FQDNs only. Everything else is denied in Enforced mode (exfiltration control).
resource "azurerm_network_security_perimeter_access_rule" "out_partner" {
  name                                  = "allow-partner-api"
  network_security_perimeter_profile_id = azurerm_network_security_perimeter_profile.data.id
  direction                             = "Outbound"
  fqdns                                 = var.allowed_outbound_fqdns
}

# ---------- Associations (membership + access mode) ----------

resource "azurerm_network_security_perimeter_association" "storage" {
  name                                  = "assoc-storage"
  network_security_perimeter_profile_id = azurerm_network_security_perimeter_profile.data.id
  resource_id                           = azurerm_storage_account.data.id
  access_mode                           = var.storage_access_mode
}

resource "azurerm_network_security_perimeter_association" "key_vault" {
  name                                  = "assoc-keyvault"
  network_security_perimeter_profile_id = azurerm_network_security_perimeter_profile.data.id
  resource_id                           = azurerm_key_vault.kv.id
  access_mode                           = var.key_vault_access_mode
}

resource "azurerm_network_security_perimeter_association" "logs" {
  name                                  = "assoc-logs"
  network_security_perimeter_profile_id = azurerm_network_security_perimeter_profile.data.id
  resource_id                           = azurerm_log_analytics_workspace.logs.id
  access_mode                           = "Learning"
}

# ---------- Access logs ----------

resource "azurerm_monitor_diagnostic_setting" "nsp" {
  name                       = "nsp-access-logs"
  target_resource_id         = azurerm_network_security_perimeter.nsp.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id

  enabled_log {
    category_group = "allLogs"
  }
}
