resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "lab" {
  name                = "${var.name_prefix}-vnet"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "aks" {
  name                              = "aks-subnet"
  resource_group_name               = azurerm_resource_group.lab.name
  virtual_network_name              = azurerm_virtual_network.lab.name
  address_prefixes                  = [var.aks_subnet_cidr]
  default_outbound_access_enabled   = false
}

resource "azurerm_subnet" "firewall" {
  name                              = "AzureFirewallSubnet"
  resource_group_name               = azurerm_resource_group.lab.name
  virtual_network_name              = azurerm_virtual_network.lab.name
  address_prefixes                  = [var.firewall_subnet_cidr]
  default_outbound_access_enabled   = false
}

resource "azurerm_subnet" "firewall_mgmt" {
  name                              = "AzureFirewallManagementSubnet"
  resource_group_name               = azurerm_resource_group.lab.name
  virtual_network_name              = azurerm_virtual_network.lab.name
  address_prefixes                  = [var.firewall_management_subnet_cidr]
  default_outbound_access_enabled   = false
}

resource "azurerm_public_ip" "fw" {
  name                = "${var.name_prefix}-fw-pip"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_version          = "IPv4"
  tags                = var.tags
}

resource "azurerm_public_ip" "fw_mgmt" {
  name                = "${var.name_prefix}-fw-mgmt-pip"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_version          = "IPv4"
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "controller" {
  name                = "${var.name_prefix}-azfw-controller"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = var.tags
}

resource "azurerm_role_assignment" "controller_network" {
  scope                = azurerm_resource_group.lab.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.controller.principal_id
}

# Existing-firewall path: a Firewall Policy (not classic rules) with the
# required AKS and *.afc.azure.com egress allows. The controller does not
# modify a supplied base policy, so these rules must already exist before
# you change AKS routing. This policy does not inherit from another base
# policy.
resource "azurerm_firewall_policy" "lab" {
  name                = "${var.name_prefix}-fwpolicy"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "Premium"
  tags                = var.tags
}

resource "azurerm_firewall_policy_rule_collection_group" "required_egress" {
  name               = "${var.name_prefix}-required-egress"
  firewall_policy_id = azurerm_firewall_policy.lab.id
  priority           = 100

  network_rule_collection {
    name     = "aks-required-network"
    priority = 100
    action   = "Allow"

    rule {
      name                  = "aks-tcp-443"
      protocols             = ["TCP"]
      source_addresses      = ["*"]
      destination_ports     = ["443"]
      destination_addresses = ["AzureKubernetesService"]
    }
  }

  application_rule_collection {
    name     = "aks-required-application"
    priority = 200
    action   = "Allow"

    rule {
      name                  = "aks-fqdn-tag-https-443"
      source_addresses      = ["*"]
      destination_fqdn_tags = ["AzureKubernetesService"]

      protocols {
        type = "Https"
        port = 443
      }
    }

    rule {
      name              = "afc-controller-https-443"
      source_addresses  = ["*"]
      destination_fqdns = ["*.afc.azure.com"]

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
  tags                = var.tags

  ip_configuration {
    name                 = "data"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.fw.id
  }

  management_ip_configuration {
    name                 = "mgmt"
    subnet_id            = azurerm_subnet.firewall_mgmt.id
    public_ip_address_id = azurerm_public_ip.fw_mgmt.id
  }

  depends_on = [azurerm_firewall_policy_rule_collection_group.required_egress]
}

# Created for the later attach step. This lab does not associate it with
# aks-subnet automatically. Associate it only after the firewall is running
# and before you apply a SecurityPolicyAttachment.
resource "azurerm_route_table" "aks" {
  name                = "${var.name_prefix}-fw-rt"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = var.tags
}

resource "azurerm_route" "to_firewall" {
  name                   = "to-firewall"
  resource_group_name    = azurerm_resource_group.lab.name
  route_table_name       = azurerm_route_table.aks.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.lab.ip_configuration[0].private_ip_address
}
