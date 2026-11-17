resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
}

locals {
  vnets = {
    a = { cidr = "10.81.0.0/16", subnet = "10.81.1.0/24" }
    b = { cidr = "10.82.0.0/16", subnet = "10.82.1.0/24" }
  }
}

# ---------------------------------------------------------------------------
# Two virtual networks with Virtual Network encryption enabled.
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "vnet" {
  for_each            = local.vnets
  name                = "${var.name_prefix}-vnet-${each.key}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  address_space       = [each.value.cidr]

  encryption {
    enforcement = var.enforcement
  }
}

resource "azurerm_subnet" "workload" {
  for_each             = local.vnets
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.vnet[each.key].name
  address_prefixes     = [each.value.subnet]
}

# Regional peering in both directions: VM-to-VM traffic across it is encrypted.
resource "azurerm_virtual_network_peering" "a_to_b" {
  name                      = "peer-a-to-b"
  resource_group_name       = azurerm_resource_group.lab.name
  virtual_network_name      = azurerm_virtual_network.vnet["a"].name
  remote_virtual_network_id = azurerm_virtual_network.vnet["b"].id
  allow_forwarded_traffic   = false
}

resource "azurerm_virtual_network_peering" "b_to_a" {
  name                      = "peer-b-to-a"
  resource_group_name       = azurerm_resource_group.lab.name
  virtual_network_name      = azurerm_virtual_network.vnet["b"].name
  remote_virtual_network_id = azurerm_virtual_network.vnet["a"].id
  allow_forwarded_traffic   = false
}

# ---------------------------------------------------------------------------
# Optional VMs: supported size, Accelerated Networking on, no public IP.
# ---------------------------------------------------------------------------
resource "azurerm_network_interface" "vm" {
  for_each                       = var.create_vms ? local.vnets : {}
  name                           = "${var.name_prefix}-nic-${each.key}"
  resource_group_name            = azurerm_resource_group.lab.name
  location                       = azurerm_resource_group.lab.location
  accelerated_networking_enabled = true

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.workload[each.key].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  for_each              = var.create_vms ? local.vnets : {}
  name                  = "${var.name_prefix}-vm-${each.key}"
  resource_group_name   = azurerm_resource_group.lab.name
  location              = azurerm_resource_group.lab.location
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.vm[each.key].id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
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

# ---------------------------------------------------------------------------
# VNet flow logs: the flow encryption field shows X (encrypted) or NX codes.
# ---------------------------------------------------------------------------
resource "random_string" "sa" {
  length  = 8
  upper   = false
  special = false
}

resource "azurerm_storage_account" "flowlogs" {
  name                     = "${var.name_prefix}fl${random_string.sa.result}"
  resource_group_name      = azurerm_resource_group.lab.name
  location                 = azurerm_resource_group.lab.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
}

resource "azurerm_network_watcher_flow_log" "vnet" {
  for_each             = local.vnets
  name                 = "${var.name_prefix}-fl-${each.key}"
  network_watcher_name = var.network_watcher_name
  resource_group_name  = var.network_watcher_resource_group
  target_resource_id   = azurerm_virtual_network.vnet[each.key].id
  storage_account_id   = azurerm_storage_account.flowlogs.id
  enabled              = true
  version              = 2

  retention_policy {
    enabled = true
    days    = var.flow_log_retention_days
  }
}
