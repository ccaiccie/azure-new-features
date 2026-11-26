resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
}

# ---------------------------------------------------------------------------
# Virtual Network and Subnets
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "lab" {
  name                = "vnet-apim-lab"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = var.vnet_address_space
}

resource "azurerm_subnet" "appgw" {
  name                 = "snet-appgw"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = [var.appgw_subnet_prefix]
}

# Classic VNet injection requires:
# - No subnet delegation (None)
# - Minimum /29 (/24 used here for clean sizing)
# - Service endpoints recommended for Azure backbone dependency paths
resource "azurerm_subnet" "apim" {
  name                 = "snet-apim"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = [var.apim_subnet_prefix]

  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.Sql",
    "Microsoft.KeyVault",
    "Microsoft.EventHub",
  ]
}

resource "azurerm_subnet" "backend" {
  name                 = "snet-backend"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = [var.backend_subnet_prefix]
}

# ---------------------------------------------------------------------------
# Network Security Groups (Official Minimum Rules)
# ---------------------------------------------------------------------------
resource "azurerm_network_security_group" "appgw" {
  name                = "nsg-appgw"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

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
    name                       = "AllowHttpInbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "appgw" {
  subnet_id                 = azurerm_subnet.appgw.id
  network_security_group_id = azurerm_network_security_group.appgw.id
}

resource "azurerm_network_security_group" "apim" {
  name                = "nsg-apim"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  # Official Inbound Rules for Internal VNet Mode
  security_rule {
    name                       = "AllowApimManagement"
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
    name                       = "AllowAzureLoadBalancer"
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
    name                       = "AllowAppGatewayToApim"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.appgw_subnet_prefix
    destination_address_prefix = var.apim_subnet_prefix
  }

  # Official Outbound Dependency Rules
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
    name                       = "AllowAzureMonitorOutbound"
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
# Note: Since May 2024, a separate Public IP resource is no longer required
# for internal VNet injection. Provisioning typically takes 30 to 40 minutes.
# ---------------------------------------------------------------------------
resource "azurerm_api_management" "lab" {
  name                 = var.apim_name
  location             = azurerm_resource_group.lab.location
  resource_group_name  = azurerm_resource_group.lab.name
  publisher_name       = var.publisher_name
  publisher_email      = var.publisher_email
  sku_name             = var.apim_sku_name
  virtual_network_type = "Internal"

  virtual_network_configuration {
    subnet_id = azurerm_subnet.apim.id
  }

  depends_on = [
    azurerm_subnet_network_security_group_association.apim
  ]
}

# ---------------------------------------------------------------------------
# Scoped Private DNS Zone (Official Critical DNS Guidance)
# IMPORTANT: Do NOT create a Private DNS zone for the apex "azure-api.net".
# Scope the zone to the exact APIM gateway FQDN so other Azure services using
# *.azure-api.net continue to resolve normally.
# ---------------------------------------------------------------------------
resource "azurerm_private_dns_zone" "apim_gateway" {
  name                = "${var.apim_name}.azure-api.net"
  resource_group_name = azurerm_resource_group.lab.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "apim_gateway" {
  name                  = "link-vnet-apim-lab"
  resource_group_name   = azurerm_resource_group.lab.name
  private_dns_zone_name = azurerm_private_dns_zone.apim_gateway.name
  virtual_network_id    = azurerm_virtual_network.lab.id
}

resource "azurerm_private_dns_a_record" "apim_gateway_apex" {
  name                = "@"
  zone_name           = azurerm_private_dns_zone.apim_gateway.name
  resource_group_name = azurerm_resource_group.lab.name
  ttl                 = 300
  records             = [azurerm_api_management.lab.private_ip_addresses[0]]
}

# ---------------------------------------------------------------------------
# Application Gateway (WAF_v2) in front of Internal API Management
# For lab simplicity, this listener accepts HTTP on port 80 externally and
# forwards HTTPS over port 443 to the APIM gateway FQDN with a custom health
# probe on /status-0123456789abcdef. In production, terminate HTTPS with a
# custom domain certificate from Key Vault.
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "appgw" {
  name                = "pip-appgw-apim-lab"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "lab" {
  name                = "agw-apim-lab"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 1
  }

  waf_configuration {
    enabled          = true
    firewall_mode    = var.appgw_waf_mode
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.appgw.id
  }

  frontend_port {
    name = "port-80"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "appgw-public-fe"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  backend_address_pool {
    name  = "apim-gateway-pool"
    fqdns = ["${var.apim_name}.azure-api.net"]
  }

  probe {
    name                                      = "apim-gateway-probe"
    protocol                                  = "Https"
    path                                      = "/status-0123456789abcdef"
    interval                                  = 30
    timeout                                   = 120
    unhealthy_threshold                       = 8
    pick_host_name_from_backend_http_settings = true

    match {
      status_code = ["200-399"]
    }
  }

  backend_http_settings {
    name                                = "apim-https-settings"
    cookie_based_affinity               = "Disabled"
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 180
    probe_name                          = "apim-gateway-probe"
    pick_host_name_from_backend_address = true
  }

  http_listener {
    name                           = "listener-http-lab"
    frontend_ip_configuration_name = "appgw-public-fe"
    frontend_port_name             = "port-80"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "rule-apim-gateway"
    priority                   = 100
    rule_type                  = "Basic"
    http_listener_name         = "listener-http-lab"
    backend_address_pool_name  = "apim-gateway-pool"
    backend_http_settings_name = "apim-https-settings"
  }

  depends_on = [
    azurerm_private_dns_a_record.apim_gateway_apex,
    azurerm_subnet_network_security_group_association.appgw
  ]
}
