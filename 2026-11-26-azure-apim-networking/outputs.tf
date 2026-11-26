output "apim_gateway_fqdn" {
  description = "Default gateway FQDN of the internal API Management instance."
  value       = "${azurerm_api_management.lab.name}.azure-api.net"
}

output "apim_private_ip" {
  description = "Private virtual IP assigned to API Management in snet-apim."
  value       = azurerm_api_management.lab.private_ip_addresses[0]
}

output "appgw_public_ip" {
  description = "Public IP address of the Application Gateway WAF_v2 frontend."
  value       = azurerm_public_ip.appgw.ip_address
}

output "health_check_url" {
  description = "Health probe URL through Application Gateway to APIM internal gateway."
  value       = "http://${azurerm_public_ip.appgw.ip_address}/status-0123456789abcdef"
}
