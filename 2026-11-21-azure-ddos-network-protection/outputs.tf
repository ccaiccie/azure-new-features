output "ddos_protection_plan_id" {
  description = "Resource ID of the Azure DDoS Network Protection Plan."
  value       = azurerm_network_ddos_protection_plan.plan.id
}

output "hub_vnet_id" {
  description = "Resource ID of the DDoS-protected Hub Virtual Network."
  value       = azurerm_virtual_network.hub.id
}

output "edge_public_ip_id" {
  description = "Resource ID of the Standard Public IP with DDoS diagnostic settings and metric alert."
  value       = azurerm_public_ip.edge.id
}
