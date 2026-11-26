output "resource_group_name" {
  description = "Resource group containing all lab resources."
  value       = azurerm_resource_group.lab.name
}

output "firewall_private_ip" {
  description = "Private IP address of Azure Firewall (used as spoke VNet DNS server and UDR next hop)."
  value       = azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

output "firewall_public_ip" {
  description = "Public IP address of Azure Firewall."
  value       = azurerm_public_ip.firewall.ip_address
}

output "spoke_vm_name" {
  description = "Name of the spoke test VM."
  value       = azurerm_linux_virtual_machine.spoke.name
}

output "spoke_vm_private_ip" {
  description = "Private IP address of the spoke test VM."
  value       = azurerm_network_interface.spoke_vm.private_ip_address
}

output "log_analytics_workspace_id" {
  description = "Workspace ID for running KQL queries against AZFWDnsQuery and AZFWNetworkRule."
  value       = azurerm_log_analytics_workspace.lab.workspace_id
}
