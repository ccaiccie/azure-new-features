output "resource_group_name" {
  description = "Resource group hosting the lab."
  value       = azurerm_resource_group.lab.name
}

output "vpn_gateway_name" {
  description = "Name of the Azure VPN Gateway."
  value       = azurerm_virtual_network_gateway.hub.name
}

output "vpn_gateway_public_ip" {
  description = "Static Standard Public IP assigned to the Azure VPN Gateway."
  value       = azurerm_public_ip.vgw.ip_address
}

output "nat_rule_summary" {
  description = "Configured Static NAT rules on the Azure VPN Gateway."
  value = {
    egress_vnet     = "${var.vnet_cidr} -> ${var.vnet_translated_cidr} (EgressSnat)"
    ingress_branch1 = "${var.branch1_cidr} -> ${var.branch1_translated_cidr} (IngressSnat)"
    ingress_branch2 = "${var.branch2_cidr} -> ${var.branch2_translated_cidr} (IngressSnat)"
  }
}

output "connection_names" {
  description = "Site-to-Site IPsec connection names."
  value = [
    azurerm_virtual_network_gateway_connection.branch1.name,
    azurerm_virtual_network_gateway_connection.branch2.name,
  ]
}
