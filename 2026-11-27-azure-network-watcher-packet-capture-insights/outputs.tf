output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "location" {
  value = azurerm_resource_group.lab.location
}

output "client_vm_public_ip" {
  value = azurerm_public_ip.client.ip_address
}

output "web_vm_private_ip" {
  value = azurerm_network_interface.web.private_ip_address
}

output "network_watcher_name" {
  value = azurerm_network_watcher.lab.name
}

output "packet_capture_name" {
  value = azurerm_virtual_machine_packet_capture.client_capture.name
}

output "packet_capture_id" {
  value = azurerm_virtual_machine_packet_capture.client_capture.id
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.insights.id
}

output "storage_account_name" {
  value = azurerm_storage_account.captures.name
}
