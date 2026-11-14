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

# Premium is required for Front Door mTLS and for the JWT authentication
# policy preview. Those controls are not arguments in azurerm 5.14.0; the
# profile is still the SKU you would use to configure them in the portal.
resource "azurerm_cdn_frontdoor_profile" "lab" {
  name                = "${var.name_prefix}-afd"
  resource_group_name = azurerm_resource_group.lab.name
  sku_name            = "Premium_AzureFrontDoor"
}

resource "azurerm_cdn_frontdoor_endpoint" "lab" {
  name                     = "${var.name_prefix}-endpoint"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.lab.id
}

resource "azurerm_cdn_frontdoor_origin_group" "lab" {
  name                     = "${var.name_prefix}-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.lab.id

  load_balancing {
    additional_latency_in_milliseconds = 0
    sample_size                        = 4
    successful_samples_required        = 3
  }

  health_probe {
    interval_in_seconds = 30
    path                = "/"
    protocol            = "Https"
    request_type        = "HEAD"
  }
}

resource "azurerm_cdn_frontdoor_origin" "lab" {
  name                          = "${var.name_prefix}-origin"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.lab.id
  enabled                       = true

  host_name                      = var.origin_host_name
  origin_host_header             = var.origin_host_name
  http_port                      = 80
  https_port                     = 443
  certificate_name_check_enabled = true
}

resource "azurerm_cdn_frontdoor_route" "lab" {
  name                          = "${var.name_prefix}-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.lab.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.lab.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.lab.id]
  supported_protocols           = ["Http", "Https"]
  patterns_to_match             = ["/*"]
  forwarding_protocol           = "HttpsOnly"
  https_redirect_enabled        = true
  link_to_default_domain        = true
}
