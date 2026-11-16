# Baseline network for the ARM MCP "query, plan, act, verify" lesson.
# Terraform creates the starting state. The NSG rule change is in
# nsg-management-ssh.bicep so you can preview it with what-if, deploy it,
# and verify it the same way the lesson describes for the ARM MCP tools.

data "azurerm_subscription" "current" {}

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

resource "azurerm_subnet" "workload" {
  name                 = "${var.name_prefix}-subnet"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = [var.subnet_cidr]
}

# Custom rules only. Azure default rules still apply. The internet SSH deny
# is the starting posture; the Bicep change adds a higher-priority allow
# from a management prefix without opening port 22 to the internet.
resource "azurerm_network_security_group" "lab" {
  name                = "${var.name_prefix}-nsg"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  security_rule {
    name                       = "DenySshFromInternet"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "Internet"
    destination_address_prefix = var.subnet_cidr
    description                = "Baseline: do not allow SSH from the internet."
  }
}

resource "azurerm_subnet_network_security_group_association" "workload" {
  subnet_id                 = azurerm_subnet.workload.id
  network_security_group_id = azurerm_network_security_group.lab.id
}
