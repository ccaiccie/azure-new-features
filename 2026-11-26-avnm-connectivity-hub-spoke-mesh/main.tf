# Azure Virtual Network Manager Connectivity Lab
# Compares Mesh vs. Hub-and-Spoke (with optional Direct Connectivity)
# Official Terraform reference:
# https://learn.microsoft.com/en-us/azure/virtual-network-manager/create-virtual-network-manager-terraform

data "azurerm_subscription" "current" {}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "azurerm_resource_group" "lab" {
  name     = "${var.resource_group_name_prefix}-${random_string.suffix.result}"
  location = var.location
}

# ---------------------------------------------------------------------------
# Virtual Networks: 1 Hub + 2 Spokes (non-overlapping address spaces)
# ---------------------------------------------------------------------------
locals {
  vnets = {
    hub = {
      name          = "vnet-hub-${random_string.suffix.result}"
      address_space = ["10.0.0.0/16"]
      subnet_prefix = ["10.0.0.0/24"]
      role          = "Hub"
    }
    spoke_a = {
      name          = "vnet-spoke-a-${random_string.suffix.result}"
      address_space = ["10.1.0.0/16"]
      subnet_prefix = ["10.1.0.0/24"]
      role          = "Spoke"
    }
    spoke_b = {
      name          = "vnet-spoke-b-${random_string.suffix.result}"
      address_space = ["10.2.0.0/16"]
      subnet_prefix = ["10.2.0.0/24"]
      role          = "Spoke"
    }
  }
}

resource "azurerm_virtual_network" "lab" {
  for_each            = local.vnets
  name                = each.value.name
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = each.value.address_space

  tags = {
    NetworkRole = each.value.role
    Lab         = "avnm-connectivity"
  }
}

resource "azurerm_subnet" "workload" {
  for_each             = local.vnets
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab[each.key].name
  address_prefixes     = each.value.subnet_prefix
}

# ---------------------------------------------------------------------------
# Azure Virtual Network Manager (Connectivity scope access)
# ---------------------------------------------------------------------------
resource "azurerm_network_manager" "lab" {
  name                = "avnm-conn-${random_string.suffix.result}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  scope_accesses      = ["Connectivity"]
  description         = "AVNM connectivity lab comparing mesh and hub-and-spoke"

  scope {
    subscription_ids = [data.azurerm_subscription.current.id]
  }
}

# Network group for the spoke VNets
resource "azurerm_network_manager_network_group" "spokes" {
  name               = "ng-spokes"
  network_manager_id = azurerm_network_manager.lab.id
  description        = "Spoke virtual networks for AVNM connectivity lab"
}

# Static membership for deterministic lab behavior (immediate update)
resource "azurerm_network_manager_static_member" "spoke_a" {
  name                      = "member-spoke-a"
  network_group_id          = azurerm_network_manager_network_group.spokes.id
  target_virtual_network_id = azurerm_virtual_network.lab["spoke_a"].id
}

resource "azurerm_network_manager_static_member" "spoke_b" {
  name                      = "member-spoke-b"
  network_group_id          = azurerm_network_manager_network_group.spokes.id
  target_virtual_network_id = azurerm_virtual_network.lab["spoke_b"].id
}

# ---------------------------------------------------------------------------
# Connectivity Configuration: Mesh OR Hub-and-Spoke
# ---------------------------------------------------------------------------
resource "azurerm_network_manager_connectivity_configuration" "mesh" {
  count                 = var.topology_mode == "mesh" ? 1 : 0
  name                  = "cc-spokes-mesh"
  network_manager_id    = azurerm_network_manager.lab.id
  connectivity_topology = "Mesh"
  description           = "Regional mesh connectivity between spoke virtual networks"

  applies_to_group {
    group_connectivity = "None"
    network_group_id   = azurerm_network_manager_network_group.spokes.id
  }
}

resource "azurerm_network_manager_connectivity_configuration" "hub_and_spoke" {
  count                 = var.topology_mode == "hub_and_spoke" ? 1 : 0
  name                  = "cc-hub-and-spoke"
  network_manager_id    = azurerm_network_manager.lab.id
  connectivity_topology = "HubAndSpoke"
  description           = "Hub-and-spoke connectivity with optional direct spoke-to-spoke mesh"

  hub {
    resource_id   = azurerm_virtual_network.lab["hub"].id
    resource_type = "Microsoft.Network/virtualNetworks"
  }

  applies_to_group {
    group_connectivity = var.enable_direct_connectivity ? "DirectlyConnected" : "None"
    network_group_id   = azurerm_network_manager_network_group.spokes.id
    use_hub_gateway    = false
  }
}

# ---------------------------------------------------------------------------
# Commit Deployment (toggle deploy_connectivity = false -> true for Before/After)
# ---------------------------------------------------------------------------
resource "azurerm_network_manager_deployment" "connectivity" {
  count              = var.deploy_connectivity ? 1 : 0
  network_manager_id = azurerm_network_manager.lab.id
  location           = azurerm_resource_group.lab.location
  scope_access       = "Connectivity"

  configuration_ids = var.topology_mode == "mesh" ? [
    azurerm_network_manager_connectivity_configuration.mesh[0].id
  ] : [
    azurerm_network_manager_connectivity_configuration.hub_and_spoke[0].id
  ]

  depends_on = [
    azurerm_network_manager_static_member.spoke_a,
    azurerm_network_manager_static_member.spoke_b
  ]
}

# ---------------------------------------------------------------------------
# Optional Lightweight Test VMs (no public IPs; test via az vm run-command)
# ---------------------------------------------------------------------------
resource "azurerm_network_interface" "vm" {
  for_each            = var.deploy_test_vms ? local.vnets : {}
  name                = "nic-${each.key}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.workload[each.key].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  for_each                        = var.deploy_test_vms ? local.vnets : {}
  name                            = "vm-${replace(each.key, "_", "-")}"
  resource_group_name             = azurerm_resource_group.lab.name
  location                        = azurerm_resource_group.lab.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.vm[each.key].id]

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
