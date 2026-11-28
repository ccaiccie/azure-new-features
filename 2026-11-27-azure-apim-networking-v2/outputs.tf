output "resource_group_name" {
  description = "Resource group containing all lab resources."
  value       = azurerm_resource_group.this.name
}

output "apim_gateway_fqdn" {
  description = "Internal APIM gateway FQDN (resolved via scoped Private DNS zone)."
  value       = "${azurerm_api_management.this.name}.azure-api.net"
}

output "apim_private_ip_addresses" {
  description = "Private Virtual IP address(es) of the internal-mode APIM instance."
  value       = azurerm_api_management.this.private_ip_addresses
}

output "private_dns_zone_name" {
  description = "Scoped Private DNS zone name (never apex azure-api.net)."
  value       = azurerm_private_dns_zone.apim_gateway.name
}

output "app_gateway_public_ip" {
  description = "Public IP address of Application Gateway WAF_v2."
  value       = azurerm_public_ip.appgw.ip_address
}
