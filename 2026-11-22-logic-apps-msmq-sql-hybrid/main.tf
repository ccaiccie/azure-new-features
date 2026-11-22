resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-${var.prefix}-${random_string.suffix.result}"
  location = var.location
  tags     = var.tags
}

# ---------------------------------------------------------------------------
# Virtual Network & Subnets
# Dedicated VNet integration subnet (Microsoft.Web/serverFarms) is strictly
# separated from the MSMQ Broker subnet.
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "lab" {
  name                = "vnet-${var.prefix}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = [var.vnet_address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "integration" {
  name                 = "snet-logicapp-integration"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = [var.integration_subnet_prefix]

  delegation {
    name = "logic-apps-vnet-integration"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action",
      ]
    }
  }
}

resource "azurerm_subnet" "broker" {
  name                 = "snet-msmq-broker"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = [var.broker_subnet_prefix]
}

# ---------------------------------------------------------------------------
# Network Security Groups
# Public-preview access control for the MSMQ Broker is private-network
# isolation: allow TCP 5050 only from the integration subnet and block public
# management ports (RDP/WinRM) and internet broker access.
# ---------------------------------------------------------------------------
resource "azurerm_network_security_group" "integration" {
  name                = "nsg-${var.prefix}-integration"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = var.tags

  security_rule {
    name                       = "Allow-Outbound-MsmqBroker-5050"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.msmq_broker_port)
    source_address_prefix      = var.integration_subnet_prefix
    destination_address_prefix = var.broker_subnet_prefix
  }
}

resource "azurerm_subnet_network_security_group_association" "integration" {
  subnet_id                 = azurerm_subnet.integration.id
  network_security_group_id = azurerm_network_security_group.integration.id
}

resource "azurerm_network_security_group" "broker" {
  name                = "nsg-${var.prefix}-broker"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = var.tags

  security_rule {
    name                       = "Allow-Inbound-MsmqBroker-From-LogicApps"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.msmq_broker_port)
    source_address_prefix      = var.integration_subnet_prefix
    destination_address_prefix = var.broker_subnet_prefix
  }

  security_rule {
    name                       = "Deny-Inbound-MsmqBroker-From-Internet"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.msmq_broker_port)
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-Inbound-Public-Management"
    priority                   = 210
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["3389", "5985", "5986"]
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "broker" {
  subnet_id                 = azurerm_subnet.broker.id
  network_security_group_id = azurerm_network_security_group.broker.id
}

# ---------------------------------------------------------------------------
# Private Windows Server 2022 VM (MSMQ + MSMQ Broker Host)
# No public IP is assigned. Manage via Azure Bastion, VPN, or ExpressRoute.
# ---------------------------------------------------------------------------
resource "azurerm_network_interface" "broker" {
  name                = "nic-${var.prefix}-broker"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = var.tags

  ip_configuration {
    name                          = "private"
    subnet_id                     = azurerm_subnet.broker.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "broker" {
  name                = "vm-msmq-broker"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  size                = var.broker_vm_size
  admin_username      = var.broker_admin_username
  admin_password      = var.broker_admin_password
  network_interface_ids = [
    azurerm_network_interface.broker.id,
  ]
  tags = var.tags

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}

# ---------------------------------------------------------------------------
# Private DNS Zone for Broker Hostname Resolution
# ---------------------------------------------------------------------------
resource "azurerm_private_dns_zone" "broker" {
  name                = var.private_dns_zone_name
  resource_group_name = azurerm_resource_group.lab.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "broker" {
  name                  = "link-${var.prefix}-dns"
  resource_group_name   = azurerm_resource_group.lab.name
  private_dns_zone_name = azurerm_private_dns_zone.broker.name
  virtual_network_id    = azurerm_virtual_network.lab.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_a_record" "broker" {
  name                = "broker"
  zone_name           = azurerm_private_dns_zone.broker.name
  resource_group_name = azurerm_resource_group.lab.name
  ttl                 = 300
  records             = [azurerm_network_interface.broker.private_ip_address]
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Optional Azure Bastion (Private RDP access without public IP on the VM)
# ---------------------------------------------------------------------------
resource "azurerm_subnet" "bastion" {
  count                = var.enable_bastion ? 1 : 0
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = [var.bastion_subnet_prefix]
}

resource "azurerm_public_ip" "bastion" {
  count               = var.enable_bastion ? 1 : 0
  name                = "pip-${var.prefix}-bastion"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "lab" {
  count               = var.enable_bastion ? 1 : 0
  name                = "bas-${var.prefix}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "Basic"
  tags                = var.tags

  ip_configuration {
    name                 = "bastion-ipcfg"
    subnet_id            = azurerm_subnet.bastion[0].id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }
}

# ---------------------------------------------------------------------------
# Azure Logic Apps Standard + VNet Integration
# Note: Azure-hosted Logic Apps Standard uses Azure Storage for runtime state.
# SQL as a storage provider (GA Nov 20, 2026) is for Hybrid Logic Apps only.
# ---------------------------------------------------------------------------
resource "azurerm_storage_account" "logicapp" {
  name                            = "st${replace(var.prefix, "-", "")}${random_string.suffix.result}"
  resource_group_name             = azurerm_resource_group.lab.name
  location                        = azurerm_resource_group.lab.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = var.tags
}

resource "azurerm_service_plan" "logicapp" {
  name                = "asp-${var.prefix}-${random_string.suffix.result}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  os_type             = "Windows"
  sku_name            = "WS1"
  tags                = var.tags
}

resource "azurerm_logic_app_standard" "lab" {
  name                       = "la-${var.prefix}-${random_string.suffix.result}"
  location                   = azurerm_resource_group.lab.location
  resource_group_name        = azurerm_resource_group.lab.name
  app_service_plan_id        = azurerm_service_plan.logicapp.id
  storage_account_name       = azurerm_storage_account.logicapp.name
  storage_account_access_key = azurerm_storage_account.logicapp.primary_access_key
  virtual_network_subnet_id  = azurerm_subnet.integration.id
  https_only                 = true
  tags                       = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    dotnet_framework_version  = "v8.0"
    use_32_bit_worker_process = false
    vnet_route_all_enabled    = true
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"     = "dotnet"
    "WEBSITE_NODE_DEFAULT_VERSION" = "~20"
  }
}
