output "resource_group_name" {
  description = "Resource group containing the lab resources."
  value       = azurerm_resource_group.lab.name
}

output "public_ip_name" {
  description = "Name of the Standard SKU public IP address."
  value       = azurerm_public_ip.lab.name
}

output "public_ip_address" {
  description = "Allocated static IPv4 address."
  value       = azurerm_public_ip.lab.ip_address
}

output "public_ip_ddos_protection_mode" {
  description = "Configured DDoS protection mode on the public IP."
  value       = azurerm_public_ip.lab.ddos_protection_mode
}

output "ddos_network_protection_plan_id" {
  description = "ID of the optional DDoS Network Protection plan (null unless enable_network_protection = true)."
  value       = var.enable_network_protection ? azurerm_network_ddos_protection_plan.optional[0].id : null
}

output "cli_validation_command" {
  description = "Run this Azure CLI command to confirm ddosSettings.protectionMode on the public IP."
  value       = "az network public-ip show --resource-group ${azurerm_resource_group.lab.name} --name ${azurerm_public_ip.lab.name} --query \"{name:name, sku:sku.name, ip:ipAddress, ddosSettings:ddosSettings}\""
}
