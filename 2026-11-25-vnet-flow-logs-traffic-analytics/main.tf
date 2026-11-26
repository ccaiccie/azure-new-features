# Azure Virtual Network Flow Logs + User-Assigned Managed Identity + Traffic Analytics Lab
# Official docs:
#   https://learn.microsoft.com/en-us/azure/network-watcher/vnet-flow-logs-overview
#   https://learn.microsoft.com/en-us/azure/network-watcher/vnet-flow-logs-managed-identity
#   https://learn.microsoft.com/en-us/azure/network-watcher/traffic-analytics

locals {
  rg_name        = "rg-${var.prefix}-vnet-flowlogs"
  storage_name   = lower("${var.prefix}flwst01")
  nw_name        = "NetworkWatcher_${var.location}"
  flow_log_name  = "${var.prefix}-vnet-flowlog"
}

resource "azurerm_resource_group" "lab" {
  name     = local.rg_name
  location = var.location
}

resource "azurerm_virtual_network" "lab" {
  name                = "${var.prefix}-vnet"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.40.0.0/16"]
}

resource "azurerm_subnet" "workload" {
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.40.1.0/24"]
}

# Example NSG with explicit Allow HTTPS outbound & Deny SSH inbound for flow-log visibility
resource "azurerm_network_security_group" "workload" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  security_rule {
    name                       = "DenySSHFromInternet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "workload" {
  subnet_id                 = azurerm_subnet.workload.id
  network_security_group_id = azurerm_network_security_group.workload.id
}

# Storage account receiving raw VNet flow log JSON blobs
resource "azurerm_storage_account" "flowlogs" {
  name                     = local.storage_name
  resource_group_name      = azurerm_resource_group.lab.name
  location                 = azurerm_resource_group.lab.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# User-assigned managed identity for credential-free flow log writes
resource "azurerm_user_assigned_identity" "flowlog_id" {
  name                = "${var.prefix}-flowlog-uami"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
}

# Required RBAC role: Storage Blob Data Contributor on the flow-log storage account
resource "azurerm_role_assignment" "flowlog_blob_contributor" {
  scope                = azurerm_storage_account.flowlogs.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.flowlog_id.principal_id
}

# Log Analytics workspace for Traffic Analytics (NTANetAnalytics table)
resource "azurerm_log_analytics_workspace" "ta" {
  name                = "${var.prefix}-law"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# Virtual Network Flow Log targeting the VNet with Managed Identity + Traffic Analytics
resource "azurerm_network_watcher_flow_log" "vnet_fl" {
  name                 = local.flow_log_name
  network_watcher_name = local.nw_name
  resource_group_name  = var.network_watcher_resource_group

  target_resource_id = azurerm_virtual_network.lab.id
  storage_account_id = azurerm_storage_account.flowlogs.id
  enabled            = true
  version            = 2

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.flowlog_id.id]
  }

  retention_policy {
    enabled = true
    days    = var.retention_days
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = azurerm_log_analytics_workspace.ta.workspace_id
    workspace_region      = azurerm_log_analytics_workspace.ta.location
    workspace_resource_id = azurerm_log_analytics_workspace.ta.id
    interval_in_minutes   = var.traffic_analytics_interval_minutes
  }

  depends_on = [azurerm_role_assignment.flowlog_blob_contributor]
}
