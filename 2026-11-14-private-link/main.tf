terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "5.14.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "random_string" "storage" {
  length  = 8
  upper   = false
  special = false
  numeric = true
}

resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "lab" {
  name                = "${var.name_prefix}-vnet"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = [var.vnet_cidr]
}

resource "azurerm_subnet" "endpoint" {
  name                 = "endpoints"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = [var.endpoint_subnet_cidr]

  # The lesson covers applying NSG and UDR network policies on private
  # endpoint subnets. "Enabled" allows both.
  private_endpoint_network_policies = "Enabled"
}

resource "azurerm_subnet" "service" {
  name                 = "services"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = [var.service_subnet_cidr]

  private_link_service_network_policies_enabled = false
}

resource "azurerm_storage_account" "lab" {
  name                            = "pllab${random_string.storage.result}"
  resource_group_name             = azurerm_resource_group.lab.name
  location                        = azurerm_resource_group.lab.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  public_network_access           = "Disabled"
  allow_nested_items_to_be_public = false
}

resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.lab.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                 = "${var.name_prefix}-blob-link"
  private_dns_zone_id  = azurerm_private_dns_zone.blob.id
  virtual_network_id   = azurerm_virtual_network.lab.id
  registration_enabled = false
}

resource "azurerm_private_endpoint" "blob" {
  name                = "${var.name_prefix}-pe-blob"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  subnet_id           = azurerm_subnet.endpoint.id
  ip_version_type     = var.ip_version_type

  private_service_connection {
    name                           = "${var.name_prefix}-blob-psc"
    private_connection_resource_id = azurerm_storage_account.lab.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "blob-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }
}

# Provider-side Private Link Service in front of an internal Standard Load
# Balancer. No virtual machines are created; the frontend is enough to form
# the service. Add a backend and a second private endpoint when you want to
# pass traffic through it.
resource "azurerm_lb" "pls" {
  name                = "${var.name_prefix}-ils"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "frontend"
    subnet_id                     = azurerm_subnet.service.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_private_link_service" "lab" {
  name                = "${var.name_prefix}-pls"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  load_balancer_frontend_ip_configuration_ids = [
    azurerm_lb.pls.frontend_ip_configuration[0].id,
  ]

  nat_ip_configuration {
    name                       = "nat"
    primary                    = true
    subnet_id                  = azurerm_subnet.service.id
    private_ip_address_version = "IPv4"
  }
}
