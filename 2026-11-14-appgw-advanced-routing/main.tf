terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "5.14.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "lab" {
  name                = "${var.name_prefix}-vnet"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = [var.vnet_cidr]
}

resource "azurerm_subnet" "appgw" {
  name                 = "appgw"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = [var.subnet_cidr]
}

resource "azurerm_public_ip" "appgw" {
  name                = "${var.name_prefix}-pip"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "lab" {
  name                = "${var.name_prefix}-appgw"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location

  sku {
    name = "Standard_v2"
    tier = "Standard_v2"
  }

  autoscale_configuration {
    min_capacity = 0
    max_capacity = 2
  }

  gateway_ip_configuration {
    name      = "gateway-ip"
    subnet_id = azurerm_subnet.appgw.id
  }

  frontend_port {
    name = "http"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "public"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  backend_address_pool {
    name  = "app-pool"
    fqdns = [var.app_backend_fqdn]
  }

  backend_address_pool {
    name  = "api-pool"
    fqdns = [var.api_backend_fqdn]
  }

  backend_http_settings {
    name                                = "http-settings"
    cookie_based_affinity               = "Disabled"
    port                                = 80
    protocol                            = "Http"
    request_timeout                     = 30
    pick_host_name_from_backend_address = true
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "public"
    frontend_port_name             = "http"
    protocol                       = "Http"
  }

  rewrite_rule_set {
    name = "add-lab-header"
    rewrite_rule {
      name          = "x-lab"
      rule_sequence = 100
      response_header_configuration {
        header_name  = "X-Lab"
        header_value = "appgw-advanced-routing"
      }
    }
  }

  url_path_map {
    name                               = "path-map"
    default_backend_address_pool_name  = "app-pool"
    default_backend_http_settings_name = "http-settings"
    default_rewrite_rule_set_name      = "add-lab-header"

    path_rule {
      name                       = "api"
      paths                      = ["/api/*"]
      backend_address_pool_name  = "api-pool"
      backend_http_settings_name = "http-settings"
      rewrite_rule_set_name      = "add-lab-header"
    }

    path_rule {
      name                       = "app"
      paths                      = ["/app/*"]
      backend_address_pool_name  = "app-pool"
      backend_http_settings_name = "http-settings"
      rewrite_rule_set_name      = "add-lab-header"
    }
  }

  request_routing_rule {
    name               = "path-based"
    rule_type          = "PathBasedRouting"
    http_listener_name = "http-listener"
    url_path_map_name  = "path-map"
    priority           = 100
  }
}
