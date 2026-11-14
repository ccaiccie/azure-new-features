output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "profile_id" {
  value = azurerm_cdn_frontdoor_profile.lab.id
}

output "profile_sku" {
  value = azurerm_cdn_frontdoor_profile.lab.sku_name
}

output "endpoint_host_name" {
  value = azurerm_cdn_frontdoor_endpoint.lab.host_name
}
