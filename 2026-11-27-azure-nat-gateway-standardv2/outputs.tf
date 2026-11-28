output "resource_group_name" {
  description = "Resource group name."
  value       = azurerm_resource_group.lab.name
}

output "nat_gateway_name" {
  description = "StandardV2 NAT Gateway name."
  value       = azurerm_nat_gateway.v2.name
}

output "nat_gateway_ipv4_address" {
  description = "StandardV2 IPv4 public IP attached to the NAT Gateway."
  value       = azurerm_public_ip.nat_v4.ip_address
}

output "nat_gateway_ipv6_address" {
  description = "StandardV2 IPv6 public IP attached to the NAT Gateway."
  value       = azurerm_public_ip.nat_v6.ip_address
}

output "test_vm_name" {
  description = "Private dual-stack test VM name."
  value       = azurerm_linux_virtual_machine.test_vm.name
}

output "log_analytics_workspace_name" {
  description = "Log Analytics workspace receiving NatGatewayFlowlogsV1."
  value       = azurerm_log_analytics_workspace.lab.name
}
