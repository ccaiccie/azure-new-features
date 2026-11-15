output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "virtual_wan_name" {
  value = azurerm_virtual_wan.lab.name
}

output "virtual_hub_id" {
  value = azurerm_virtual_hub.lab.id
}

output "firewall_id" {
  value = azurerm_firewall.lab.id
}

output "routing_intent_name" {
  value = azurerm_virtual_hub_routing_intent.lab.name
}

output "spoke_vnet_name" {
  value = azurerm_virtual_network.spoke.name
}
