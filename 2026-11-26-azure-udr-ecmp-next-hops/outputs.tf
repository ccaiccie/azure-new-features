output "resource_group_name" {
  description = "Resource group containing the ECMP lab."
  value       = azurerm_resource_group.lab.name
}

output "nva_private_ips" {
  description = "Private IP addresses of the hub NVA VMs configured as ECMP next hops."
  value       = [for nic in azurerm_network_interface.nva : nic.private_ip_address]
}

output "source_vm_private_ip" {
  description = "Private IP address of vm-src-spoke-a."
  value       = azurerm_network_interface.src.private_ip_address
}

output "destination_vm_private_ip" {
  description = "Private IP address of vm-dest-spoke-b."
  value       = azurerm_network_interface.dest.private_ip_address
}

output "verify_route_cli" {
  description = "Azure CLI command to inspect the saved ECMP route."
  value       = "az network route-table route show --resource-group ${azurerm_resource_group.lab.name} --route-table-name ${azurerm_route_table.spoke_a.name} --name to-spoke-b-ecmp --query '{addressPrefix:addressPrefix,nextHopType:nextHopType,nextHop:nextHop,provisioningState:provisioningState}' --output json"
}

output "verify_effective_routes_cli" {
  description = "Azure CLI command to inspect effective routes on the Spoke A source VM NIC."
  value       = "az network nic show-effective-route-table --resource-group ${azurerm_resource_group.lab.name} --name ${azurerm_network_interface.src.name} --output table"
}
