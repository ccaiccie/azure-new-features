output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "application_gateway_name" {
  value = azurerm_application_gateway.lab.name
}

output "public_ip" {
  value = azurerm_public_ip.appgw.ip_address
}
