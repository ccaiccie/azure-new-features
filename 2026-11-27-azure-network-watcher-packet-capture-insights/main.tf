resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
}

# Ensure a Network Watcher exists in the lab region.
# If your subscription already has NetworkWatcher_<region> in NetworkWatcherRG,
# replace this resource with a data source referencing that existing watcher.
resource "azurerm_network_watcher" "lab" {
  name                = "nw-pcap-insights-${var.location}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
}

# Standard storage account in the same region as the target VM.
# Premium storage accounts are not supported for Network Watcher packet captures.
# Storage account key access must be enabled so Network Watcher can use SAS tokens.
resource "azurerm_storage_account" "captures" {
  name                            = "stpcap${random_string.suffix.result}"
  resource_group_name             = azurerm_resource_group.lab.name
  location                        = azurerm_resource_group.lab.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  shared_access_key_enabled       = true
  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"
}

# Log Analytics workspace in the SAME subscription and SAME region as the packet capture resource.
resource "azurerm_log_analytics_workspace" "insights" {
  name                = "law-pcap-insights-${random_string.suffix.result}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_virtual_network" "lab" {
  name                = "vnet-pcap-insights"
  address_space       = ["10.42.0.0/16"]
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
}

resource "azurerm_subnet" "workload" {
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.42.1.0/24"]
}

resource "azurerm_network_security_group" "workload" {
  name                = "nsg-pcap-workload"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  security_rule {
    name                       = "AllowSSHFromAdmin"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_source_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHttpHttpsFromVnet"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }
}

resource "azurerm_subnet_network_security_group_association" "workload" {
  subnet_id                 = azurerm_subnet.workload.id
  network_security_group_id = azurerm_network_security_group.workload.id
}

resource "azurerm_public_ip" "client" {
  name                = "pip-client-vm"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "client" {
  name                = "nic-client-vm"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.workload.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.42.1.10"
    public_ip_address_id          = azurerm_public_ip.client.id
  }
}

resource "azurerm_network_interface" "web" {
  name                = "nic-web-vm"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.workload.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.42.1.20"
  }
}

resource "azurerm_linux_virtual_machine" "client" {
  name                = "client-vm"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  size                = var.vm_size
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.client.id,
  ]

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

resource "azurerm_linux_virtual_machine" "web" {
  name                = "web-vm"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  size                = var.vm_size
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.web.id,
  ]

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

  # Install nginx with a self-signed TLS cert on port 443 and plain HTTP on port 80
  custom_data = base64encode(<<-EOF
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y nginx openssl
    mkdir -p /etc/nginx/certs
    openssl req -x509 -nodes -days 30 -newkey rsa:2048 \
      -keyout /etc/nginx/certs/web.key \
      -out /etc/nginx/certs/web.crt \
      -subj "/CN=web.lab.internal"
    cat >/etc/nginx/sites-available/default <<'NGINX'
    server {
      listen 80 default_server;
      listen 443 ssl default_server;
      ssl_certificate /etc/nginx/certs/web.crt;
      ssl_certificate_key /etc/nginx/certs/web.key;
      ssl_protocols TLSv1.2 TLSv1.3;
      location / {
        return 200 "hello from web-vm\n";
      }
      location /slow {
        return 200 "ok from /slow\n";
      }
      location /missing {
        return 404 "not found\n";
      }
    }
    NGINX
    systemctl restart nginx
  EOF
  )
}

# Install Network Watcher Agent VM extension on both VMs
resource "azurerm_virtual_machine_extension" "nw_agent_client" {
  name                       = "AzureNetworkWatcherExtension"
  virtual_machine_id         = azurerm_linux_virtual_machine.client.id
  publisher                  = "Microsoft.Azure.NetworkWatcher"
  type                       = "NetworkWatcherAgentLinux"
  type_handler_version       = "1.4"
  auto_upgrade_minor_version = true
}

resource "azurerm_virtual_machine_extension" "nw_agent_web" {
  name                       = "AzureNetworkWatcherExtension"
  virtual_machine_id         = azurerm_linux_virtual_machine.web.id
  publisher                  = "Microsoft.Azure.NetworkWatcher"
  type                       = "NetworkWatcherAgentLinux"
  type_handler_version       = "1.4"
  auto_upgrade_minor_version = true
}

# Network Watcher packet capture targeting client-vm with filters for DNS, HTTP, and TLS.
# KNOWN PROVIDER GAP: azurerm has no resource for packet capture insights yet.
# After generating traffic and stopping this capture, call startInsight via REST API or Portal.
resource "azurerm_virtual_machine_packet_capture" "client_capture" {
  name                         = "pcap-client-insights-lab"
  network_watcher_id           = azurerm_network_watcher.lab.id
  virtual_machine_id           = azurerm_linux_virtual_machine.client.id
  maximum_bytes_per_packet     = 0
  maximum_bytes_per_session    = var.capture_total_bytes
  maximum_capture_duration_in_seconds = var.capture_time_limit_seconds

  storage_location {
    storage_account_id = azurerm_storage_account.captures.id
  }

  filter {
    protocol    = "UDP"
    remote_port = "53"
  }

  filter {
    protocol    = "TCP"
    remote_port = "80;443"
  }

  depends_on = [
    azurerm_virtual_machine_extension.nw_agent_client,
    azurerm_virtual_machine_extension.nw_agent_web,
  ]
}
