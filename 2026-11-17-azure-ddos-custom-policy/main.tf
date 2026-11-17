resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "lab" {
  name                = "${var.name_prefix}-vnet"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "lab" {
  name                 = "${var.name_prefix}-snet"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = [var.subnet_cidr]
}

resource "azurerm_public_ip" "front" {
  name                = "${var.name_prefix}-pip"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_lb" "lab" {
  name                = "${var.name_prefix}-lb"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                 = "public"
    public_ip_address_id = azurerm_public_ip.front.id
  }
}

resource "azurerm_lb_backend_address_pool" "lab" {
  name            = "backend"
  loadbalancer_id = azurerm_lb.lab.id
}

# The AzureRM 5.14.0 provider does not yet ship azurerm_network_ddos_custom_policy.
# Deploy the generally available Microsoft.Network/ddosCustomPolicies resource with an ARM template.
resource "azurerm_resource_group_template_deployment" "custom_policy" {
  name                = "${var.name_prefix}-ddos-custom-policy"
  resource_group_name = azurerm_resource_group.lab.name
  deployment_mode     = "Incremental"
  template_content    = file("${path.module}/ddos-custom-policy.json")
  parameters_content = jsonencode({
    policyName = {
      value = "${var.name_prefix}-ddos-custom-policy"
    }
    location = {
      value = azurerm_resource_group.lab.location
    }
    frontendIPConfigurationId = {
      value = azurerm_lb.lab.frontend_ip_configuration[0].id
    }
    synThreshold = {
      value = var.tcp_syn_threshold_pps
    }
  })
}
