terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "5.14.0"
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

resource "azurerm_virtual_network" "lab" {
  name                = "${var.name_prefix}-vnet"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = [var.ipv4_address_space, var.ipv6_address_space]
}

# Microsoft's dual-stack tutorial adds an IPv6 /64 to RouteServerSubnet
# before creating Route Server. With that prefix present, a new Route Server
# is created in dual-stack mode. azurerm 5.14.0 has no dual_stack_mode argument.
resource "azurerm_subnet" "route_server" {
  name                 = "RouteServerSubnet"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = [var.route_server_ipv4_prefix, var.route_server_ipv6_prefix]
}

resource "azurerm_subnet" "nva" {
  name                 = "nva"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = [var.nva_ipv4_prefix, var.nva_ipv6_prefix]
}

resource "azurerm_public_ip" "route_server" {
  name                = "${var.name_prefix}-rs-pip"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_route_server" "lab" {
  name                             = "${var.name_prefix}-rs"
  resource_group_name              = azurerm_resource_group.lab.name
  location                         = azurerm_resource_group.lab.location
  sku                              = "Standard"
  public_ip_address_id             = azurerm_public_ip.route_server.id
  subnet_id                        = azurerm_subnet.route_server.id
  branch_to_branch_traffic_enabled = var.branch_to_branch_traffic_enabled
}
