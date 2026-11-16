output "network_manager_id" {
  description = "Resource ID of the Virtual Network Manager."
  value       = azurerm_network_manager.lab.id
}

output "security_admin_configuration_id" {
  description = "Resource ID of the deployed security admin configuration."
  value       = azurerm_network_manager_security_admin_configuration.central.id
}

output "governed_vnet_ids" {
  description = "Virtual networks in the governed network group."
  value       = { for k, v in azurerm_virtual_network.vnet : k => v.id }
}
