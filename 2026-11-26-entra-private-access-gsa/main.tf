# ------------------------------------------------------------------------------
# Azure Infrastructure for Microsoft Entra Private Access (GSA) Lab
# Creates: Resource Group, VNet, Private Subnet, NSG, Windows Server 2022
# Connector Host VM, and a Private Linux HTTP Target VM (zero public IPs).
# ------------------------------------------------------------------------------

resource "azurerm_resource_group" "lab" {
  name     = "rg-${var.prefix}-entra-private-access"
  location = var.location
}

resource "azurerm_virtual_network" "lab" {
  name                = "${var.prefix}-vnet"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.70.0.0/16"]
}

resource "azurerm_subnet" "private" {
  name                 = "snet-private-apps"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.70.1.0/24"]
}

resource "azurerm_network_security_group" "private" {
  name                = "${var.prefix}-private-nsg"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  # Outbound HTTPS (443) and HTTP (80 for CRL/OCSP) required by the private network connector
  security_rule {
    name                       = "AllowConnectorOutbound443And80"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "Internet"
  }
}

resource "azurerm_subnet_network_security_group_association" "private" {
  subnet_id                 = azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.private.id
}

# 1. Windows Server 2022 host for Microsoft Entra Private Network Connector
resource "azurerm_network_interface" "connector" {
  name                = "${var.prefix}-connector-nic"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.private.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "connector" {
  name                = "${var.prefix}-conn-vm"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  size                = "Standard_B2ms"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [
    azurerm_network_interface.connector.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}

# 2. Private Internal App Target VM (no public IP — reached via Entra Private Access)
resource "azurerm_network_interface" "target" {
  name                = "${var.prefix}-target-nic"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.private.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "target" {
  name                            = "${var.prefix}-private-app"
  resource_group_name             = azurerm_resource_group.lab.name
  location                        = azurerm_resource_group.lab.location
  size                            = "Standard_B1s"
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.target.id,
  ]

  custom_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update -y && apt-get install -y nginx
    echo "<h1>Entra Private Access Lab Target (Private IP Only)</h1>" > /var/www/html/index.html
    systemctl enable --now nginx
  EOF
  )

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
