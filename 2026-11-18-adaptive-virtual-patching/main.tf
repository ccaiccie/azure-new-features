resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
}

locals {
  tags = {
    lab      = "adaptive-virtual-patching"
    workload = "linux-web"
  }

  # nginx on 80 plus a stand-in "vulnerable" service on 8080 (a second nginx server block).
  cloud_init = <<-CLOUDINIT
    #cloud-config
    package_update: true
    packages:
      - nginx
    write_files:
      - path: /etc/nginx/sites-enabled/legacy-8080
        content: |
          server {
            listen 8080;
            location / { return 200 "legacy service on 8080 on $hostname\n"; }
          }
    runcmd:
      - systemctl restart nginx
  CLOUDINIT
}

# ---------------------------------------------------------------------------
# Network: one VNet, a subnet for the VM and one for the scale set.
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "lab" {
  name                = "${var.name_prefix}-vnet"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  address_space       = ["10.90.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "vm" {
  name                            = "snet-vm"
  resource_group_name             = azurerm_resource_group.lab.name
  virtual_network_name            = azurerm_virtual_network.lab.name
  address_prefixes                = ["10.90.1.0/24"]
  default_outbound_access_enabled = false
}

resource "azurerm_subnet" "vmss" {
  name                            = "snet-vmss"
  resource_group_name             = azurerm_resource_group.lab.name
  virtual_network_name            = azurerm_virtual_network.lab.name
  address_prefixes                = ["10.90.2.0/24"]
  default_outbound_access_enabled = false
}

# Explicit outbound (apt updates and patches) through a NAT gateway.
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

resource "azurerm_subnet_nat_gateway_association" "vm" {
  subnet_id      = azurerm_subnet.vm.id
  nat_gateway_id = azurerm_nat_gateway.lab.id
}

resource "azurerm_subnet_nat_gateway_association" "vmss" {
  subnet_id      = azurerm_subnet.vmss.id
  nat_gateway_id = azurerm_nat_gateway.lab.id
}

# ---------------------------------------------------------------------------
# NSG: only your own prefix reaches SSH, 80 and 8080. Shared by both subnets.
# ---------------------------------------------------------------------------
resource "azurerm_network_security_group" "lab" {
  name                = "${var.name_prefix}-nsg"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  tags                = local.tags

  security_rule {
    name                       = "allow-ssh-from-me"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.allowed_source_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-web-from-me"
    priority                   = 210
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", tostring(var.mitigation_port)]
    source_address_prefix      = var.allowed_source_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-lb-probe"
    priority                   = 220
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }
}

# Manual practice of the virtual-patching lifecycle (NOT the Adaptive Virtual Patching service):
# a temporary, high-priority deny for the exposed port. Set temporary_mitigation_enabled = false to roll it back.
resource "azurerm_network_security_rule" "temporary_mitigation" {
  count                       = var.temporary_mitigation_enabled ? 1 : 0
  name                        = "temp-mitigation-deny-${var.mitigation_port}"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = tostring(var.mitigation_port)
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.lab.name
  network_security_group_name = azurerm_network_security_group.lab.name
  description                 = "Temporary compensating control until the patch is deployed and confirmed. Remove after remediation."
}

resource "azurerm_subnet_network_security_group_association" "vm" {
  subnet_id                 = azurerm_subnet.vm.id
  network_security_group_id = azurerm_network_security_group.lab.id
}

resource "azurerm_subnet_network_security_group_association" "vmss" {
  subnet_id                 = azurerm_subnet.vmss.id
  network_security_group_id = azurerm_network_security_group.lab.id
}

# ---------------------------------------------------------------------------
# Target 1: a single Linux VM with a public IP and platform patch assessment.
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "vm" {
  name                = "${var.name_prefix}-pip-vm"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_network_interface" "vm" {
  name                = "${var.name_prefix}-nic-vm"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  tags                = local.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }
}

resource "azurerm_linux_virtual_machine" "web" {
  name                  = "${var.name_prefix}-vm-web"
  resource_group_name   = azurerm_resource_group.lab.name
  location              = azurerm_resource_group.lab.location
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.vm.id]
  custom_data           = base64encode(local.cloud_init)
  provision_vm_agent    = true
  patch_assessment_mode = "AutomaticByPlatform"
  tags                  = merge(local.tags, { role = "single-vm" })

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

  depends_on = [azurerm_subnet_nat_gateway_association.vm]
}

# ---------------------------------------------------------------------------
# Target 2: a Linux scale set behind a Standard public Load Balancer.
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "lb" {
  name                = "${var.name_prefix}-pip-lb"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_lb" "web" {
  name                = "${var.name_prefix}-lb"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  sku                 = "Standard"
  tags                = local.tags

  frontend_ip_configuration {
    name                 = "fe-public"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "web" {
  name            = "be-vmss"
  loadbalancer_id = azurerm_lb.web.id
}

resource "azurerm_lb_probe" "http" {
  name            = "probe-http"
  loadbalancer_id = azurerm_lb.web.id
  protocol        = "Http"
  port            = 80
  request_path    = "/"
}

resource "azurerm_lb_rule" "http" {
  name                           = "rule-http"
  loadbalancer_id                = azurerm_lb.web.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "fe-public"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web.id]
  probe_id                       = azurerm_lb_probe.http.id
  disable_outbound_snat          = true
}

resource "azurerm_lb_rule" "legacy" {
  name                           = "rule-legacy-${var.mitigation_port}"
  loadbalancer_id                = azurerm_lb.web.id
  protocol                       = "Tcp"
  frontend_port                  = var.mitigation_port
  backend_port                   = var.mitigation_port
  frontend_ip_configuration_name = "fe-public"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web.id]
  probe_id                       = azurerm_lb_probe.http.id
  disable_outbound_snat          = true
}

resource "azurerm_linux_virtual_machine_scale_set" "web" {
  name                = "${var.name_prefix}-vmss-web"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  sku                 = var.vm_size
  instances           = var.vmss_instances
  admin_username      = var.admin_username
  custom_data         = base64encode(local.cloud_init)
  upgrade_mode        = "Manual"
  tags                = merge(local.tags, { role = "scale-set" })

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

  network_interface {
    name    = "nic"
    primary = true

    ip_configuration {
      name                                   = "ipconfig1"
      primary                                = true
      subnet_id                              = azurerm_subnet.vmss.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.web.id]
    }
  }

  depends_on = [azurerm_lb_rule.http, azurerm_subnet_nat_gateway_association.vmss]
}
