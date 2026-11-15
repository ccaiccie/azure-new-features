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

resource "azurerm_virtual_wan" "lab" {
  name                = "${var.name_prefix}-vwan"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  type                = "Standard"
}

resource "azurerm_virtual_hub" "lab" {
  name                = "${var.name_prefix}-hub"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  virtual_wan_id      = azurerm_virtual_wan.lab.id
  address_prefix      = var.hub_address_prefix
  sku                 = "Standard"
}

resource "azurerm_firewall_policy" "lab" {
  name                = "${var.name_prefix}-fwpolicy"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  sku                 = "Standard"

  # Lab only: a single allow-all network rule so you can confirm routing
  # intent steers traffic. Tighten this before any real workload uses the hub.
}

resource "azurerm_firewall_policy_rule_collection_group" "lab" {
  name               = "lab-allow"
  firewall_policy_id = azurerm_firewall_policy.lab.id
  priority           = 100

  network_rule_collection {
    name     = "allow-all-lab"
    priority = 100
    action   = "Allow"

    rule {
      name                  = "allow-all"
      protocols             = ["Any"]
      source_addresses      = ["*"]
      destination_addresses = ["*"]
      destination_ports     = ["*"]
    }
  }
}

resource "azurerm_firewall" "lab" {
  name                = "${var.name_prefix}-azfw"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku_name            = "AZFW_Hub"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.lab.id

  virtual_hub {
    virtual_hub_id  = azurerm_virtual_hub.lab.id
    public_ip_count = 1
  }
}

resource "azurerm_virtual_hub_routing_intent" "lab" {
  name           = "${var.name_prefix}-intent"
  virtual_hub_id = azurerm_virtual_hub.lab.id

  routing_policy {
    name         = "InternetTrafficPolicy"
    destinations = ["Internet"]
    next_hop     = azurerm_firewall.lab.id
  }

  routing_policy {
    name         = "PrivateTrafficPolicy"
    destinations = ["PrivateTraffic"]
    next_hop     = azurerm_firewall.lab.id
  }

  depends_on = [azurerm_firewall_policy_rule_collection_group.lab]
}

resource "azurerm_virtual_network" "spoke" {
  name                = "${var.name_prefix}-spoke"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = [var.spoke_cidr]
}

resource "azurerm_subnet" "spoke" {
  name                 = "workload"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.spoke_subnet_cidr]
}

resource "azurerm_virtual_hub_connection" "spoke" {
  name                      = "${var.name_prefix}-spoke-conn"
  virtual_hub_id            = azurerm_virtual_hub.lab.id
  remote_virtual_network_id = azurerm_virtual_network.spoke.id
  internet_security_enabled = true

  depends_on = [azurerm_virtual_hub_routing_intent.lab]
}
