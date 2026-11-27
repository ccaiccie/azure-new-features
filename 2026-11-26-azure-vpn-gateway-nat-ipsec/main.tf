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

# 1. Resource Group
resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# 2. Azure Virtual Network (10.0.1.0/24 — overlaps with Branch 1 and Branch 2)
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-azure-hub"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "workload" {
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.workload_subnet_cidr]
}

# GatewaySubnet name is strictly required by Azure VPN Gateway
resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.gateway_subnet_cidr]
}

# 3. Standard Static Public IP for the VPN Gateway
resource "azurerm_public_ip" "vgw" {
  name                = "pip-vgw-azure-hub"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# 4. Route-Based VPN Gateway
# Lowest-cost officially supported SKU for VPN Gateway NAT is VpnGw2.
# Official Microsoft Learn docs state NAT is supported on VpnGw2~5 and VpnGw2AZ~5AZ only.
# Provisioning typically takes 30 to 45+ minutes and bills hourly until deleted.
resource "azurerm_virtual_network_gateway" "hub" {
  name                = "vgw-azure-hub"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  type       = "Vpn"
  vpn_type   = "RouteBased"
  sku        = var.vpn_gateway_sku
  generation = var.vpn_gateway_generation

  active_active                         = false
  bgp_enabled                           = false
  bgp_route_translation_for_nat_enabled = false

  ip_configuration {
    name                          = "default"
    public_ip_address_id          = azurerm_public_ip.vgw.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }

  tags = var.tags
}

# Read back the gateway IP configuration ID for NAT rule binding
data "azurerm_virtual_network_gateway" "hub" {
  name                = azurerm_virtual_network_gateway.hub.name
  resource_group_name = azurerm_virtual_network_gateway.hub.resource_group_name
}

# 5. Simulated On-Premises Local Network Gateways (overlapping 10.0.1.0/24)
resource "azurerm_local_network_gateway" "branch1" {
  name                = "lng-branch1"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  gateway_address     = var.branch1_peer_ip
  address_space       = [var.branch1_cidr]
  tags                = var.tags
}

resource "azurerm_local_network_gateway" "branch2" {
  name                = "lng-branch2"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  gateway_address     = var.branch2_peer_ip
  address_space       = [var.branch2_cidr]
  tags                = var.tags
}

# 6. VPN Gateway NAT Rules (must be created BEFORE connections are linked)
# EgressSNAT: translates Azure VNet 10.0.1.0/24 -> 192.168.1.0/24
resource "azurerm_virtual_network_gateway_nat_rule" "egress_vnet" {
  name                       = "nat-egress-vnet"
  resource_group_name        = azurerm_resource_group.lab.name
  virtual_network_gateway_id = data.azurerm_virtual_network_gateway.hub.id
  mode                       = "EgressSnat"
  type                       = "Static"
  ip_configuration_id        = data.azurerm_virtual_network_gateway.hub.ip_configuration[0].id

  internal_mapping {
    address_space = var.vnet_cidr
  }

  external_mapping {
    address_space = var.vnet_translated_cidr
  }
}

# IngressSNAT for Branch 1: translates 10.0.1.0/24 -> 192.168.2.0/24
resource "azurerm_virtual_network_gateway_nat_rule" "ingress_branch1" {
  name                       = "nat-ingress-branch1"
  resource_group_name        = azurerm_resource_group.lab.name
  virtual_network_gateway_id = data.azurerm_virtual_network_gateway.hub.id
  mode                       = "IngressSnat"
  type                       = "Static"
  ip_configuration_id        = data.azurerm_virtual_network_gateway.hub.ip_configuration[0].id

  internal_mapping {
    address_space = var.branch1_cidr
  }

  external_mapping {
    address_space = var.branch1_translated_cidr
  }
}

# IngressSNAT for Branch 2: translates 10.0.1.0/24 -> 192.168.3.0/24
resource "azurerm_virtual_network_gateway_nat_rule" "ingress_branch2" {
  name                       = "nat-ingress-branch2"
  resource_group_name        = azurerm_resource_group.lab.name
  virtual_network_gateway_id = data.azurerm_virtual_network_gateway.hub.id
  mode                       = "IngressSnat"
  type                       = "Static"
  ip_configuration_id        = data.azurerm_virtual_network_gateway.hub.ip_configuration[0].id

  internal_mapping {
    address_space = var.branch2_cidr
  }

  external_mapping {
    address_space = var.branch2_translated_cidr
  }
}

# 7. Site-to-Site IPsec Connections with NAT rules + Custom IPsec/IKE Policies
# Note: use_policy_based_traffic_selectors MUST remain false when NAT rules are attached.
resource "azurerm_virtual_network_gateway_connection" "branch1" {
  name                = "conn-vnet-to-branch1"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  type                               = "IPsec"
  connection_protocol                = "IKEv2"
  virtual_network_gateway_id         = azurerm_virtual_network_gateway.hub.id
  local_network_gateway_id           = azurerm_local_network_gateway.branch1.id
  shared_key                         = var.vpn_shared_key
  dpd_timeout_seconds                = 45
  use_policy_based_traffic_selectors = false

  ingress_nat_rule_ids = [azurerm_virtual_network_gateway_nat_rule.ingress_branch1.id]
  egress_nat_rule_ids  = [azurerm_virtual_network_gateway_nat_rule.egress_vnet.id]

  # Custom IPsec/IKE Policy (GCMAES256 paired for IPsec encryption & integrity)
  ipsec_policy {
    ike_encryption   = "AES256"
    ike_integrity    = "SHA384"
    dh_group         = "DHGroup24"
    ipsec_encryption = "GCMAES256"
    ipsec_integrity  = "GCMAES256"
    pfs_group        = "PFS24"
    sa_lifetime      = 14400
    sa_datasize      = 102400000
  }

  tags = var.tags
}

resource "azurerm_virtual_network_gateway_connection" "branch2" {
  name                = "conn-vnet-to-branch2"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  type                               = "IPsec"
  connection_protocol                = "IKEv2"
  virtual_network_gateway_id         = azurerm_virtual_network_gateway.hub.id
  local_network_gateway_id           = azurerm_local_network_gateway.branch2.id
  shared_key                         = var.vpn_shared_key
  dpd_timeout_seconds                = 45
  use_policy_based_traffic_selectors = false

  ingress_nat_rule_ids = [azurerm_virtual_network_gateway_nat_rule.ingress_branch2.id]
  egress_nat_rule_ids  = [azurerm_virtual_network_gateway_nat_rule.egress_vnet.id]

  # Per-connection Custom IPsec/IKE Policy (AES256/SHA256 + ECP384)
  ipsec_policy {
    ike_encryption   = "AES256"
    ike_integrity    = "SHA256"
    dh_group         = "ECP384"
    ipsec_encryption = "AES256"
    ipsec_integrity  = "SHA256"
    pfs_group        = "ECP384"
    sa_lifetime      = 27000
    sa_datasize      = 102400000
  }

  tags = var.tags
}
