terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.20.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "lab" {
  name                = "${var.prefix}-vnet"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = [var.vnet_ipv4_cidr, var.vnet_ipv6_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "workload" {
  name                            = "${var.prefix}-subnet"
  resource_group_name             = azurerm_resource_group.lab.name
  virtual_network_name            = azurerm_virtual_network.lab.name
  address_prefixes                = [var.subnet_ipv4_cidr, var.subnet_ipv6_cidr]
  default_outbound_access_enabled = false
}

# StandardV2 NAT Gateway requires StandardV2 SKU Public IPs.
# Standard and Basic Public IPs are not supported with StandardV2.
resource "azurerm_public_ip" "nat_v4" {
  name                = "${var.prefix}-pip-v4"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "StandardV2"
  ip_version          = "IPv4"
  tags                = var.tags
}

resource "azurerm_public_ip" "nat_v6" {
  name                = "${var.prefix}-pip-v6"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "StandardV2"
  ip_version          = "IPv6"
  tags                = var.tags
}

# StandardV2 NAT Gateway is zone-redundant by default.
# Omit the zones argument when sku_name = "StandardV2".
resource "azurerm_nat_gateway" "v2" {
  name                    = "${var.prefix}-natgw-v2"
  location                = azurerm_resource_group.lab.location
  resource_group_name     = azurerm_resource_group.lab.name
  sku_name                = "StandardV2"
  idle_timeout_in_minutes = var.idle_timeout_in_minutes
  tags                    = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "v4" {
  nat_gateway_id       = azurerm_nat_gateway.v2.id
  public_ip_address_id = azurerm_public_ip.nat_v4.id
}

resource "azurerm_nat_gateway_public_ip_association" "v6" {
  nat_gateway_id       = azurerm_nat_gateway.v2.id
  public_ip_address_id = azurerm_public_ip.nat_v6.id
}

resource "azurerm_subnet_nat_gateway_association" "workload" {
  subnet_id      = azurerm_subnet.workload.id
  nat_gateway_id = azurerm_nat_gateway.v2.id
}

# Log Analytics Workspace + Diagnostic Setting for NatGatewayFlowlogsV1
resource "azurerm_log_analytics_workspace" "lab" {
  name                = "${var.prefix}-law"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "nat_flow_logs" {
  name                       = "${var.prefix}-nat-flowlogs"
  target_resource_id         = azurerm_nat_gateway.v2.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.lab.id

  enabled_log {
    category = "NatGatewayFlowlogsV1"
  }
}

# Small private dual-stack Linux test VM (no public IP on the VM itself)
resource "azurerm_network_interface" "test_vm" {
  name                = "${var.prefix}-vm-nic"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = var.tags

  ip_configuration {
    name                          = "ipv4-config"
    subnet_id                     = azurerm_subnet.workload.id
    private_ip_address_allocation = "Dynamic"
    private_ip_address_version    = "IPv4"
    primary                       = true
  }

  ip_configuration {
    name                          = "ipv6-config"
    subnet_id                     = azurerm_subnet.workload.id
    private_ip_address_allocation = "Dynamic"
    private_ip_address_version    = "IPv6"
  }
}

resource "azurerm_linux_virtual_machine" "test_vm" {
  name                = "${var.prefix}-vm"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  size                = var.vm_size
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.test_vm.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
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

  tags = var.tags
}
