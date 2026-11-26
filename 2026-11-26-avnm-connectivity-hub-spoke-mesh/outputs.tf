output "resource_group_name" {
  value       = azurerm_resource_group.lab.name
  description = "Resource group hosting the AVNM connectivity lab."
}

output "network_manager_name" {
  value       = azurerm_network_manager.lab.name
  description = "Azure Virtual Network Manager instance name."
}

output "virtual_network_names" {
  value       = { for k, v in azurerm_virtual_network.lab : k => v.name }
  description = "Created hub and spoke virtual network names."
}

output "test_vm_private_ips" {
  value       = { for k, nic in azurerm_network_interface.vm : k => nic.private_ip_address }
  description = "Private IP addresses of the test VMs for ping verification."
}

output "active_topology_mode" {
  value       = var.topology_mode
  description = "Currently selected AVNM connectivity topology."
}

output "connectivity_deployed" {
  value       = var.deploy_connectivity
  description = "Whether the connectivity configuration is currently committed to the target region."
}
