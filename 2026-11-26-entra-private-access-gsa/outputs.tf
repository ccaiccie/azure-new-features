output "resource_group_name" {
  description = "Lab Azure Resource Group name."
  value       = azurerm_resource_group.lab.name
}

output "vnet_name" {
  description = "Lab Azure Virtual Network name."
  value       = azurerm_virtual_network.lab.name
}

output "connector_host_private_ip" {
  description = "Private IP address of the Windows Server 2022 connector host VM."
  value       = azurerm_network_interface.connector.private_ip_address
}

output "private_target_ip" {
  description = "Private IP address of the internal HTTP target VM (publish this in Quick Access or per-app access)."
  value       = azurerm_network_interface.target.private_ip_address
}
