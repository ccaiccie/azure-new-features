# ==============================================================================
# Azure Virtual Network ECMP Next Hops for UDRs — Public Preview Practice Lab
# Hub-and-Spoke Topology with Dedicated NVA Subnet and VirtualApplianceEcmp UDR
# ==============================================================================

locals {
  nva_cloud_init = base64encode(<<-EOF
    #cloud-config
    package_update: true
    packages:
      - tcpdump
      - traceroute
    write_files:
      - path: /etc/sysctl.d/99-ipforward.conf
        content: |
          net.ipv4.ip_forward = 1
    runcmd:
      - sysctl -p /etc/sysctl.d/99-ipforward.conf
  EOF
  )

  spoke_cloud_init = base64encode(<<-EOF
    #cloud-config
    package_update: true
    packages:
      - curl
      - iputils-tracepath
      - python3
  EOF
  )
}

resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
  tags = {
    lab     = "azure-udr-ecmp-next-hops"
    feature = "public-preview"
  }
}

# ------------------------------------------------------------------------------
# Hub VNet (10.10.0.0/16) — Dedicated NVA Subnet (10.10.1.0/24)
# Separate subnet from source workloads to avoid routing loops.
# ------------------------------------------------------------------------------
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.10.0.0/16"]
}

resource "azurerm_subnet" "nva" {
  name                 = "snet-nva"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.10.1.0/24"]
}

# ------------------------------------------------------------------------------
# Spoke A VNet (10.20.0.0/16) — Source Workload Subnet (10.20.1.0/24)
# ------------------------------------------------------------------------------
resource "azurerm_virtual_network" "spoke_a" {
  name                = "vnet-spoke-a"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.20.0.0/16"]
}

resource "azurerm_subnet" "spoke_a_workload" {
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.spoke_a.name
  address_prefixes     = ["10.20.1.0/24"]
}

# ------------------------------------------------------------------------------
# Spoke B VNet (10.30.0.0/16) — Destination Subnet (10.30.1.0/24)
# ------------------------------------------------------------------------------
resource "azurerm_virtual_network" "spoke_b" {
  name                = "vnet-spoke-b"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.30.0.0/16"]
}

resource "azurerm_subnet" "spoke_b_dest" {
  name                 = "snet-dest"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.spoke_b.name
  address_prefixes     = ["10.30.1.0/24"]
}

# ------------------------------------------------------------------------------
# Hub-to-Spoke VNet Peerings (Forwarded Traffic Enabled)
# ------------------------------------------------------------------------------
resource "azurerm_virtual_network_peering" "hub_to_spoke_a" {
  name                      = "peer-hub-to-spoke-a"
  resource_group_name       = azurerm_resource_group.lab.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke_a.id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "spoke_a_to_hub" {
  name                      = "peer-spoke-a-to-hub"
  resource_group_name       = azurerm_resource_group.lab.name
  virtual_network_name      = azurerm_virtual_network.spoke_a.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "hub_to_spoke_b" {
  name                      = "peer-hub-to-spoke-b"
  resource_group_name       = azurerm_resource_group.lab.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke_b.id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "spoke_b_to_hub" {
  name                      = "peer-spoke-b-to-hub"
  resource_group_name       = azurerm_resource_group.lab.name
  virtual_network_name      = azurerm_virtual_network.spoke_b.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
}

# ------------------------------------------------------------------------------
# Network Virtual Appliances (NVAs) in Hub snet-nva
# IP forwarding enabled on BOTH each NIC and inside the Linux guest OS.
# ------------------------------------------------------------------------------
resource "azurerm_network_interface" "nva" {
  count                 = var.nva_count
  name                  = "nic-nva-${count.index + 1}"
  location              = azurerm_resource_group.lab.location
  resource_group_name   = azurerm_resource_group.lab.name
  ip_forwarding_enabled = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.nva.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost("10.10.1.0/24", 4 + count.index)
  }
}

resource "azurerm_linux_virtual_machine" "nva" {
  count               = var.nva_count
  name                = "vm-nva-${count.index + 1}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  size                = var.vm_size
  admin_username      = var.admin_username
  custom_data         = local.nva_cloud_init

  network_interface_ids = [
    azurerm_network_interface.nva[count.index].id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
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

# ------------------------------------------------------------------------------
# Source Workload VM (Spoke A) and Destination VM (Spoke B)
# ------------------------------------------------------------------------------
resource "azurerm_network_interface" "src" {
  name                = "nic-src-spoke-a"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.spoke_a_workload.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.20.1.4"
  }
}

resource "azurerm_linux_virtual_machine" "src" {
  name                = "vm-src-spoke-a"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  size                = var.vm_size
  admin_username      = var.admin_username
  custom_data         = local.spoke_cloud_init

  network_interface_ids = [azurerm_network_interface.src.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
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

resource "azurerm_network_interface" "dest" {
  name                = "nic-dest-spoke-b"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.spoke_b_dest.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.30.1.4"
  }
}

resource "azurerm_linux_virtual_machine" "dest" {
  name                = "vm-dest-spoke-b"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  size                = var.vm_size
  admin_username      = var.admin_username
  custom_data         = local.spoke_cloud_init

  network_interface_ids = [azurerm_network_interface.dest.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
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

# ------------------------------------------------------------------------------
# Route Table + Public Preview ECMP Route (VirtualApplianceEcmp)
# Uses AzAPI Microsoft.Network/routeTables/routes@2026-03-01 for nextHop list.
# Prerequisite: Microsoft.Network/AllowEcmpInRoute registered on subscription.
# ------------------------------------------------------------------------------
resource "azurerm_route_table" "spoke_a" {
  name                = "rt-spoke-a-ecmp"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
}

resource "azapi_resource" "ecmp_to_spoke_b" {
  type      = "Microsoft.Network/routeTables/routes@2026-03-01"
  name      = "to-spoke-b-ecmp"
  parent_id = azurerm_route_table.spoke_a.id

  body = {
    properties = {
      addressPrefix = "10.30.1.0/24"
      nextHopType   = "VirtualApplianceEcmp"
      nextHop = {
        nextHopIpAddresses = [
          for nic in azurerm_network_interface.nva : nic.private_ip_address
        ]
      }
    }
  }

  depends_on = [azurerm_linux_virtual_machine.nva]
}

resource "azurerm_subnet_route_table_association" "spoke_a" {
  subnet_id      = azurerm_subnet.spoke_a_workload.id
  route_table_id = azurerm_route_table.spoke_a.id
  depends_on     = [azapi_resource.ecmp_to_spoke_b]
}

# Return route from Spoke B back to Spoke A via the hub NVAs (also ECMP).
# Note: ECMP does not guarantee return-path symmetry across stateful NVAs.
resource "azurerm_route_table" "spoke_b" {
  name                = "rt-spoke-b-ecmp"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
}

resource "azapi_resource" "ecmp_to_spoke_a" {
  type      = "Microsoft.Network/routeTables/routes@2026-03-01"
  name      = "to-spoke-a-ecmp"
  parent_id = azurerm_route_table.spoke_b.id

  body = {
    properties = {
      addressPrefix = "10.20.1.0/24"
      nextHopType   = "VirtualApplianceEcmp"
      nextHop = {
        nextHopIpAddresses = [
          for nic in azurerm_network_interface.nva : nic.private_ip_address
        ]
      }
    }
  }

  depends_on = [azurerm_linux_virtual_machine.nva]
}

resource "azurerm_subnet_route_table_association" "spoke_b" {
  subnet_id      = azurerm_subnet.spoke_b_dest.id
  route_table_id = azurerm_route_table.spoke_b.id
  depends_on     = [azapi_resource.ecmp_to_spoke_a]
}
