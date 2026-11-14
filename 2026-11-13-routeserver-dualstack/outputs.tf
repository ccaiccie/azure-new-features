output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "virtual_network_name" {
  value = azurerm_virtual_network.lab.name
}

output "route_server_name" {
  value = azurerm_route_server.lab.name
}

output "route_server_id" {
  value = azurerm_route_server.lab.id
}

output "virtual_router_ips" {
  description = "IPv4 addresses the NVA would peer with over BGP, including for IPv6 routes via multiprotocol BGP."
  value       = azurerm_route_server.lab.virtual_router_ips
}

output "virtual_router_asn" {
  value = azurerm_route_server.lab.virtual_router_asn
}
