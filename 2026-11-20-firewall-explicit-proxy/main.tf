data "azurerm_client_config" "current" {}

locals {
  pac_blob_name = "proxy.pac"
  # Storage account names: 3-24 lowercase letters and digits.
  storage_name = substr("${var.name_prefix}pac${random_string.suffix.result}", 0, 24)
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ---------------------------------------------------------------------------
# Network: one VNet, the firewall subnet, and a client subnet with NO route table.
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "lab" {
  name                = "${var.name_prefix}-vnet"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = [var.firewall_subnet_cidr]
}

resource "azurerm_subnet" "client" {
  name                 = "client"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = [var.client_subnet_cidr]
}

# ---------------------------------------------------------------------------
# PAC file hosting: storage account, container, blob, read-only SAS URL,
# and a user-assigned identity (name must start with PacFileMSI-) that can
# read the blob.
# ---------------------------------------------------------------------------
resource "azurerm_storage_account" "pac" {
  name                            = local.storage_name
  resource_group_name             = azurerm_resource_group.lab.name
  location                        = azurerm_resource_group.lab.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true # needed to mint the account-key SAS below
  tags                            = var.tags
}

resource "azurerm_storage_container" "pac" {
  name                  = "explicitproxycontainer"
  storage_account_id    = azurerm_storage_account.pac.id
  container_access_type = "private"
}

resource "azurerm_storage_blob" "pac" {
  name                 = local.pac_blob_name
  storage_container_id = azurerm_storage_container.pac.id
  type                 = "Block"
  content_type         = "application/x-ns-proxy-autoconfig"
  source_content = templatefile("${path.module}/proxy.pac.tftpl", {
    proxy_ip   = var.firewall_private_ip
    proxy_port = var.proxy_http_port
  })
}

data "azurerm_storage_account_blob_container_sas" "pac" {
  connection_string = azurerm_storage_account.pac.primary_connection_string
  container_name    = azurerm_storage_container.pac.name
  https_only        = true

  start  = var.sas_start
  expiry = var.sas_expiry

  permissions {
    read   = true
    add    = false
    create = false
    write  = false
    delete = false
    list   = false
  }
}

resource "azurerm_user_assigned_identity" "pac" {
  name                = "PacFileMSI-${var.name_prefix}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = var.tags
}

resource "azurerm_role_assignment" "pac_contributor" {
  scope                = azurerm_storage_account.pac.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.pac.principal_id
}

resource "azurerm_role_assignment" "pac_reader" {
  scope                = azurerm_storage_account.pac.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.pac.principal_id
}

# ---------------------------------------------------------------------------
# Firewall policy with the explicit proxy block. Explicit proxy lives on the
# POLICY, not on the firewall resource.
# ---------------------------------------------------------------------------
resource "azurerm_firewall_policy" "lab" {
  name                = "${var.name_prefix}-policy"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = var.firewall_sku_tier
  tags                = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.pac.id]
  }

  explicit_proxy {
    enabled         = true
    http_port       = var.proxy_http_port
    https_port      = var.proxy_https_port
    enable_pac_file = true
    pac_file_port   = var.pac_file_port
    pac_file        = "${azurerm_storage_blob.pac.url}${data.azurerm_storage_account_blob_container_sas.pac.sas}"
  }

  depends_on = [
    azurerm_role_assignment.pac_contributor,
    azurerm_role_assignment.pac_reader,
  ]
}

# Explicit proxy traffic is judged by APPLICATION rules. A network rule would not match it.
resource "azurerm_firewall_policy_rule_collection_group" "web" {
  name               = "explicit-proxy-web"
  firewall_policy_id = azurerm_firewall_policy.lab.id
  priority           = 200

  application_rule_collection {
    name     = "allow-web"
    priority = 200
    action   = "Allow"

    rule {
      name = "allowed-sites"
      protocols {
        type = "Http"
        port = 80
      }
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = [var.client_subnet_cidr]
      destination_fqdns = var.allowed_fqdns
    }
  }
}

# ---------------------------------------------------------------------------
# Firewall (Standard by default) using that policy.
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "firewall" {
  name                = "${var.name_prefix}-fw-pip"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall" "lab" {
  name                = "${var.name_prefix}-fw"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku_name            = "AZFW_VNet"
  sku_tier            = var.firewall_sku_tier
  firewall_policy_id  = azurerm_firewall_policy.lab.id
  tags                = var.tags

  ip_configuration {
    name                 = "primary"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }

  depends_on = [azurerm_firewall_policy_rule_collection_group.web]
}

# The PAC file was rendered with var.firewall_private_ip before the firewall existed.
# This check warns if Azure picked a different address.
check "pac_points_at_firewall" {
  assert {
    condition     = azurerm_firewall.lab.ip_configuration[0].private_ip_address == var.firewall_private_ip
    error_message = "The firewall private IP is ${azurerm_firewall.lab.ip_configuration[0].private_ip_address} but the PAC file points at ${var.firewall_private_ip}. Set firewall_private_ip to the real address and apply again."
  }
}

# ---------------------------------------------------------------------------
# Optional test client. No public IP, no route table, no UDR.
# ---------------------------------------------------------------------------
resource "random_password" "vm" {
  count            = var.create_test_vm ? 1 : 0
  length           = 24
  special          = true
  override_special = "!#%*-_"
}

resource "azurerm_network_interface" "client" {
  count               = var.create_test_vm ? 1 : 0
  name                = "${var.name_prefix}-client-nic"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = var.tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.client.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "client" {
  count                           = var.create_test_vm ? 1 : 0
  name                            = "${var.name_prefix}-client"
  location                        = azurerm_resource_group.lab.location
  resource_group_name             = azurerm_resource_group.lab.name
  size                            = "Standard_B1s"
  admin_username                  = "labadmin"
  admin_password                  = random_password.vm[0].result
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.client[0].id]
  tags                            = var.tags

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
