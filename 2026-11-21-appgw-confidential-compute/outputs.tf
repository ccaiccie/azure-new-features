output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "application_gateway_id" {
  value = azurerm_application_gateway.lab.id
}

output "public_ip" {
  value = azurerm_public_ip.appgw.ip_address
}

output "location" {
  value = azurerm_resource_group.lab.location
}
