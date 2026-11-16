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

data "azurerm_subscription" "current" {}

resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
}

# ---------------------------------------------------------------------------
# Two virtual networks that the central team will govern, plus an NSG that an
# application team wrote. The NSG tries to deny 443 inbound, so we can see an
# Always Allow security admin rule win over it.
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "vnet" {
  for_each            = var.vnets
  name                = "${var.name_prefix}-${each.key}-vnet"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  address_space       = [each.value.cidr]
}

resource "azurerm_subnet" "workload" {
  for_each             = var.vnets
  name                 = "workload"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.vnet[each.key].name
  address_prefixes     = [each.value.subnet_cidr]
}

resource "azurerm_network_security_group" "app_team" {
  name                = "${var.name_prefix}-app-team-nsg"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location

  security_rule {
    name                       = "app-team-deny-https-in"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "app_team" {
  for_each                  = var.vnets
  subnet_id                 = azurerm_subnet.workload[each.key].id
  network_security_group_id = azurerm_network_security_group.app_team.id
}

# ---------------------------------------------------------------------------
# Azure Virtual Network Manager scoped to this subscription, with the
# SecurityAdmin feature turned on.
# ---------------------------------------------------------------------------
resource "azurerm_network_manager" "lab" {
  name                = "${var.name_prefix}-avnm"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  scope_accesses      = ["SecurityAdmin"]
  description         = "Central governance for the security admin rules lab"

  scope {
    subscription_ids = [data.azurerm_subscription.current.id]
  }
}

resource "azurerm_network_manager_network_group" "governed" {
  name               = "ng-governed"
  network_manager_id = azurerm_network_manager.lab.id
  description        = "VNets that receive the central rules"
}

resource "azurerm_network_manager_static_member" "vnet" {
  for_each                  = var.vnets
  name                      = "member-${each.key}"
  network_group_id          = azurerm_network_manager_network_group.governed.id
  target_virtual_network_id = azurerm_virtual_network.vnet[each.key].id
}

# ---------------------------------------------------------------------------
# One security admin configuration (only one can be deployed per region),
# one rule collection, and three rules that show Always Allow, Allow and Deny.
# ---------------------------------------------------------------------------
resource "azurerm_network_manager_security_admin_configuration" "central" {
  name               = "central-security"
  network_manager_id = azurerm_network_manager.lab.id
  description        = "Global rules evaluated before NSGs"
}

resource "azurerm_network_manager_admin_rule_collection" "baseline" {
  name                            = "baseline"
  security_admin_configuration_id = azurerm_network_manager_security_admin_configuration.central.id
  network_group_ids               = [azurerm_network_manager_network_group.governed.id]
  description                     = "Baseline rules for governed VNets"
}

# Always Allow: ends evaluation, so the application team's NSG deny on 443 cannot break the monitoring probe.
resource "azurerm_network_manager_admin_rule" "monitoring_always_allow" {
  name                     = "always-allow-monitoring-https"
  admin_rule_collection_id = azurerm_network_manager_admin_rule_collection.baseline.id
  action                   = "AlwaysAllow"
  direction                = "Inbound"
  priority                 = 10
  protocol                 = "Tcp"
  source_port_ranges       = ["0-65535"]
  destination_port_ranges  = ["443"]
  description              = "Monitoring must always reach 443"

  source {
    address_prefix_type = "IPPrefix"
    address_prefix      = var.monitoring_prefix
  }

  destination {
    address_prefix_type = "IPPrefix"
    address_prefix      = "*"
  }
}

# Allow: lets the management subnet reach SSH, then hands the packet to the NSGs for the final word.
resource "azurerm_network_manager_admin_rule" "bastion_allow_ssh" {
  name                     = "allow-bastion-ssh"
  admin_rule_collection_id = azurerm_network_manager_admin_rule_collection.baseline.id
  action                   = "Allow"
  direction                = "Inbound"
  priority                 = 20
  protocol                 = "Tcp"
  source_port_ranges       = ["0-65535"]
  destination_port_ranges  = ["22"]
  description              = "Exception: management subnet may use SSH"

  source {
    address_prefix_type = "IPPrefix"
    address_prefix      = var.bastion_prefix
  }

  destination {
    address_prefix_type = "IPPrefix"
    address_prefix      = "*"
  }
}

# Deny: nothing from the Internet service tag reaches high-risk management ports.
resource "azurerm_network_manager_admin_rule" "deny_risky_from_internet" {
  name                     = "deny-risky-ports-from-internet"
  admin_rule_collection_id = azurerm_network_manager_admin_rule_collection.baseline.id
  action                   = "Deny"
  direction                = "Inbound"
  priority                 = 100
  protocol                 = "Tcp"
  source_port_ranges       = ["0-65535"]
  destination_port_ranges  = var.high_risk_ports
  description              = "Block high-risk ports from the Internet"

  source {
    address_prefix_type = "ServiceTag"
    address_prefix      = "Internet"
  }

  destination {
    address_prefix_type = "IPPrefix"
    address_prefix      = "*"
  }
}

# ---------------------------------------------------------------------------
# Rules do nothing until the configuration is DEPLOYED to a region.
# ---------------------------------------------------------------------------
resource "azurerm_network_manager_deployment" "central" {
  network_manager_id = azurerm_network_manager.lab.id
  location           = azurerm_resource_group.lab.location
  scope_access       = "SecurityAdmin"
  configuration_ids  = [azurerm_network_manager_security_admin_configuration.central.id]

  depends_on = [
    azurerm_network_manager_admin_rule.monitoring_always_allow,
    azurerm_network_manager_admin_rule.bastion_allow_ssh,
    azurerm_network_manager_admin_rule.deny_risky_from_internet,
    azurerm_network_manager_static_member.vnet,
  ]
}
