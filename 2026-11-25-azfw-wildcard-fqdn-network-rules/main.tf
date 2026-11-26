terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
}

# ------------------------------------------------------------------------------
# Hub Virtual Network & Azure Firewall Subnet
# ------------------------------------------------------------------------------
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub-azfw"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.1.0/26"]
}

# ------------------------------------------------------------------------------
# Spoke Virtual Network & Workload Subnet
# ------------------------------------------------------------------------------
resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-spoke-app"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "workload" {
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = ["10.1.1.0/24"]
}

# ------------------------------------------------------------------------------
# Hub-and-Spoke VNet Peering
# ------------------------------------------------------------------------------
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                      = "peer-hub-to-spoke"
  resource_group_name       = azurerm_resource_group.lab.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke.id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "peer-spoke-to-hub"
  resource_group_name       = azurerm_resource_group.lab.name
  virtual_network_name      = azurerm_virtual_network.spoke.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
}

# ------------------------------------------------------------------------------
# Azure Firewall Standard + Policy with DNS Proxy Enabled
# ------------------------------------------------------------------------------
resource "azurerm_public_ip" "firewall" {
  name                = "pip-azfw-hub"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall_policy" "hub" {
  name                = "afwp-hub-wildcard"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = var.firewall_sku

  dns {
    proxy_enabled = true
    servers       = var.custom_dns_servers
  }
}

resource "azurerm_firewall" "hub" {
  name                = "afw-hub-wildcard"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku_name            = "AZFW_VNet"
  sku_tier            = var.firewall_sku
  firewall_policy_id  = azurerm_firewall_policy.hub.id

  ip_configuration {
    name                 = "fw-ipconfig"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
}

# ------------------------------------------------------------------------------
# Point Spoke VNet DNS to Azure Firewall Private IP
# ------------------------------------------------------------------------------
resource "azurerm_virtual_network_dns_servers" "spoke" {
  virtual_network_id = azurerm_virtual_network.spoke.id
  dns_servers        = [azurerm_firewall.hub.ip_configuration[0].private_ip_address]
}

# ------------------------------------------------------------------------------
# Force Spoke Outbound Traffic Through Azure Firewall
# ------------------------------------------------------------------------------
resource "azurerm_route_table" "spoke" {
  name                = "rt-spoke-to-azfw"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  route {
    name                   = "default-to-azfw"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.hub.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "spoke_workload" {
  subnet_id      = azurerm_subnet.workload.id
  route_table_id = azurerm_route_table.spoke.id
}

# ------------------------------------------------------------------------------
# Network Rule Collection with Wildcard FQDN
# ------------------------------------------------------------------------------
resource "azurerm_firewall_policy_rule_collection_group" "wildcard_demo" {
  name               = "rcg-wildcard-network"
  firewall_policy_id = azurerm_firewall_policy.hub.id
  priority           = 200

  network_rule_collection {
    name     = "allow-wildcard-non-http"
    priority = 200
    action   = "Allow"

    rule {
      name              = "allow-ntp-wildcard"
      protocols         = ["UDP"]
      source_addresses  = ["10.1.1.0/24"]
      destination_fqdns = [var.wildcard_ntp_fqdn]
      destination_ports = ["123"]
    }

    rule {
      name              = "allow-contoso-ssh-tcp"
      protocols         = ["TCP"]
      source_addresses  = ["10.1.1.0/24"]
      destination_fqdns = [var.wildcard_app_fqdn]
      destination_ports = ["22", "443"]
    }
  }
}

# ------------------------------------------------------------------------------
# Log Analytics Workspace & Resource-Specific Diagnostic Logs
# ------------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "lab" {
  name                = var.log_analytics_workspace_name
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_monitor_diagnostic_setting" "firewall" {
  name                           = "diag-azfw-wildcard"
  target_resource_id             = azurerm_firewall.hub.id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.lab.id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category = "AZFWNetworkRule"
  }

  enabled_log {
    category = "AZFWDnsQuery"
  }
}

# ------------------------------------------------------------------------------
# Spoke Test Virtual Machine (No Public IP - verify via az vm run-command)
# ------------------------------------------------------------------------------
resource "azurerm_network_interface" "spoke_vm" {
  name                = "nic-vm-spoke-01"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.workload.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.1.1.4"
  }

  depends_on = [azurerm_virtual_network_dns_servers.spoke]
}

resource "azurerm_linux_virtual_machine" "spoke" {
  name                = "vm-spoke-01"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  size                = var.vm_size
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.spoke_vm.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}
