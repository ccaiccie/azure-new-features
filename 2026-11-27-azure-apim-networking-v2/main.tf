# Azure API Management Networking (Internal VNet + Application Gateway WAF_v2 + Scoped Private DNS)
# Follows official Microsoft Learn guidance:
# - https://learn.microsoft.com/en-us/azure/api-management/api-management-using-with-internal-vnet
# - https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-integrate-internal-vnet-appgateway

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ---------------------------------------------------------------------------
# Virtual Network and Subnets
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "this" {
  name                = "vnet-apim-v2"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.20.0.0/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "appgw" {
  name                 = "snet-appgw"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.20.0.0/24"]
}

# Classic APIM internal VNet injection requires a non-delegated subnet with an attached NSG.
resource "azurerm_subnet" "apim" {
  name                 = "snet-apim"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.20.1.0/24"]
  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.Sql",
    "Microsoft.KeyVault",
    "Microsoft.EventHub",
  ]
}

resource "azurerm_subnet" "backend" {
  name                 = "snet-backend"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.20.2.0/24"]
}

# ---------------------------------------------------------------------------
# Network Security Groups (Minimum Official Rules)
# ---------------------------------------------------------------------------
resource "azurerm_network_security_group" "appgw" {
  name                = "nsg-appgw-v2"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags

  security_rule {
    name                       = "AllowGatewayManager"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHttpsFromInternet"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHttpLabFromInternet"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "appgw" {
  subnet_id                 = azurerm_subnet.appgw.id
  network_security_group_id = azurerm_network_security_group.appgw.id
}

resource "azurerm_network_security_group" "apim" {
  name                = "nsg-apim-v2"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags

  # Official minimum inbound rules for Internal VNet mode
  security_rule {
    name                       = "AllowApimControlPlane3443"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3443"
    source_address_prefix      = "ApiManagement"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowAzureLoadBalancer6390"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6390"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowAppGatewayHttps"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "10.20.0.0/24"
    destination_address_prefix = "10.20.1.0/24"
  }

  # Official minimum outbound rules for Azure platform dependencies
  security_rule {
    name                       = "AllowStorageOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "Storage"
  }

  security_rule {
    name                       = "AllowSqlOutbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "Sql"
  }

  security_rule {
    name                       = "AllowKeyVaultOutbound"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "AzureKeyVault"
  }

  security_rule {
    name                       = "AllowMonitorOutbound"
    priority                   = 130
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["1886", "443"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "AzureMonitor"
  }

  security_rule {
    name                       = "AllowCertValidationHttp"
    priority                   = 140
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "Internet"
  }
}

resource "azurerm_subnet_network_security_group_association" "apim" {
  subnet_id                 = azurerm_subnet.apim.id
  network_security_group_id = azurerm_network_security_group.apim.id
}

# ---------------------------------------------------------------------------
# Azure API Management (Internal VNet Mode)
# Starting May 2024, a customer-managed Public IP is NOT required for Internal mode.
# Provisioning takes ~30-40 minutes for Developer_1 in Internal VNet mode.
# ---------------------------------------------------------------------------
resource "azurerm_api_management" "this" {
  name                 = var.apim_name
  location             = azurerm_resource_group.this.location
  resource_group_name  = azurerm_resource_group.this.name
  publisher_name       = var.publisher_name
  publisher_email      = var.publisher_email
  sku_name             = var.apim_sku_name
  virtual_network_type = "Internal"
  tags                 = var.tags

  virtual_network_configuration {
    subnet_id = azurerm_subnet.apim.id
  }

  depends_on = [azurerm_subnet_network_security_group_association.apim]
}

# ---------------------------------------------------------------------------
# Scoped Private DNS Zone (NEVER create a Private DNS zone for apex azure-api.net!)
# ---------------------------------------------------------------------------
resource "azurerm_private_dns_zone" "apim_gateway" {
  name                = "${azurerm_api_management.this.name}.azure-api.net"
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "apim_gateway" {
  name                  = "link-vnet-apim-v2"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.apim_gateway.name
  virtual_network_id    = azurerm_virtual_network.this.id
}

resource "azurerm_private_dns_a_record" "apim_gateway_apex" {
  name                = "@"
  zone_name           = azurerm_private_dns_zone.apim_gateway.name
  resource_group_name = azurerm_resource_group.this.name
  ttl                 = 300
  records             = azurerm_api_management.this.private_ip_addresses
}

# ---------------------------------------------------------------------------
# Application Gateway (WAF_v2) Fronting Internal APIM
# Uses custom HTTPS health probe /status-0123456789abcdef with APIM Host header
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "appgw" {
  name                = "pip-agw-apim-v2"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_application_gateway" "this" {
  name                = "agw-apim-v2"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = var.appgw_capacity
  }

  waf_configuration {
    enabled          = true
    firewall_mode    = "Prevention"
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }

  gateway_ip_configuration {
    name      = "agw-ip-config"
    subnet_id = azurerm_subnet.appgw.id
  }

  frontend_port {
    name = "port-http-lab"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "agw-public-ip"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  backend_address_pool {
    name  = "apim-internal-pool"
    fqdns = ["${azurerm_api_management.this.name}.azure-api.net"]
  }

  probe {
    name                                      = "probe-apim-gateway"
    protocol                                  = "Https"
    host                                      = "${azurerm_api_management.this.name}.azure-api.net"
    path                                      = "/status-0123456789abcdef"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = false
  }

  backend_http_settings {
    name                                = "apim-https-settings"
    cookie_based_affinity               = "Disabled"
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 60
    host_name                           = "${azurerm_api_management.this.name}.azure-api.net"
    pick_host_name_from_backend_address = false
    probe_name                          = "probe-apim-gateway"
  }

  http_listener {
    name                           = "listener-http-lab"
    frontend_ip_configuration_name = "agw-public-ip"
    frontend_port_name             = "port-http-lab"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "rule-apim-gateway"
    priority                   = 100
    rule_type                  = "Basic"
    http_listener_name         = "listener-http-lab"
    backend_address_pool_name  = "apim-internal-pool"
    backend_http_settings_name = "apim-https-settings"
  }

  depends_on = [
    azurerm_private_dns_a_record.apim_gateway_apex,
    azurerm_private_dns_zone_virtual_network_link.apim_gateway,
  ]
}
