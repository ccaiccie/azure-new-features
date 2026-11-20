locals {
  tags = {
    lab     = "2026-11-20-azure-infrastructure-agentic-ai"
    purpose = "practice-lab"
  }

  storage_account_name = "st${var.name_prefix}${var.unique_suffix}"
}

resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

# ---------------------------------------------------------------------------
# Virtual network and subnets
# Address spaces are illustrative teaching values, not production prefixes.
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "lab" {
  name                = "${var.name_prefix}-vnet"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  address_space       = [var.vnet_cidr]
  tags                = local.tags
}

resource "azurerm_subnet" "sandbox" {
  name                 = "snet-sandbox"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = [var.sandbox_subnet_cidr]

  # Official ACI sandbox virtual-network tutorial: associate a NAT gateway
  # and set default outbound access to true for internet egress.
  default_outbound_access_enabled = true

  # Provider gap (hashicorp/azurerm 5.14.0): the official delegation
  # Microsoft.ContainerInstance/AIAgentsGroups is not in the provider's
  # allow-list, so this lab cannot set it in Terraform. Add the delegation
  # after apply with Azure CLI or ARM, as documented in the README.
}

resource "azurerm_subnet" "private_endpoints" {
  name                            = "snet-private-endpoints"
  resource_group_name             = azurerm_resource_group.lab.name
  virtual_network_name            = azurerm_virtual_network.lab.name
  address_prefixes                = [var.private_endpoint_subnet_cidr]
  default_outbound_access_enabled = false

  # Classic private-endpoint behavior; no NSG on this subnet in this lab.
  private_endpoint_network_policies = "Disabled"
}

# ---------------------------------------------------------------------------
# NAT gateway for sandbox-subnet egress (official tutorial pattern)
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "nat" {
  name                = "${var.name_prefix}-pip-nat"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_nat_gateway" "lab" {
  name                = "${var.name_prefix}-natgw"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  sku_name            = "Standard"
  tags                = local.tags
}

resource "azurerm_nat_gateway_public_ip_association" "lab" {
  nat_gateway_id       = azurerm_nat_gateway.lab.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "sandbox" {
  subnet_id      = azurerm_subnet.sandbox.id
  nat_gateway_id = azurerm_nat_gateway.lab.id
}

# ---------------------------------------------------------------------------
# NSG on the delegated sandbox subnet
# Official docs: for VNet-connected ACI sandboxes, isolation depends on this
# subnet, and you use an NSG to allow or deny traffic in either direction.
# These rules are a starting lab posture, not a production policy pack.
# ---------------------------------------------------------------------------
resource "azurerm_network_security_group" "sandbox" {
  name                = "${var.name_prefix}-nsg-sandbox"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  tags                = local.tags

  security_rule {
    name                       = "allow-inbound-vnet"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "allow-inbound-load-balancer"
    priority                   = 210
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "deny-inbound-internet"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-outbound-vnet"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "allow-outbound-internet-via-nat"
    priority                   = 210
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }
}

resource "azurerm_subnet_network_security_group_association" "sandbox" {
  subnet_id                 = azurerm_subnet.sandbox.id
  network_security_group_id = azurerm_network_security_group.sandbox.id
}

# ---------------------------------------------------------------------------
# Identity: user-assigned identity for the (later) AI agents group
# Official agent-identity tutorial uses this identity for federated exchange
# to an Entra Agent ID. Do not treat this identity as the agent itself.
# ---------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "group" {
  name                = "${var.name_prefix}-id-group"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  tags                = local.tags
}

# ---------------------------------------------------------------------------
# Private storage for artifacts and saved state (official foundation mentions
# Azure Blob and File Storage). No GPU SKUs and no Azure OpenAI in this lab.
# ---------------------------------------------------------------------------
resource "azurerm_storage_account" "artifacts" {
  name                            = local.storage_account_name
  resource_group_name             = azurerm_resource_group.lab.name
  location                        = azurerm_resource_group.lab.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  public_network_access           = "Disabled"
  allow_nested_items_to_be_public = false
  https_traffic_only_enabled      = true
  tags                            = local.tags
}

resource "azurerm_storage_container" "artifacts" {
  name                  = "agent-artifacts"
  storage_account_id    = azurerm_storage_account.artifacts.id
  container_access_type = "private"
}

resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                 = "${var.name_prefix}-blob-dns-link"
  private_dns_zone_id  = azurerm_private_dns_zone.blob.id
  virtual_network_id   = azurerm_virtual_network.lab.id
  registration_enabled = false
  tags                 = local.tags
}

resource "azurerm_private_endpoint" "blob" {
  name                = "${var.name_prefix}-pe-blob"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.tags

  private_service_connection {
    name                           = "${var.name_prefix}-psc-blob"
    private_connection_resource_id = azurerm_storage_account.artifacts.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "blob-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }
}

# ---------------------------------------------------------------------------
# Monitoring surround. Viewing platform metrics does not require this
# workspace; it is here so you can send resource logs if you want them.
# ---------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "lab" {
  name                = "${var.name_prefix}-law"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = local.tags
}

