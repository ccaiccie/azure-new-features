output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "vnet_flow_log_name" {
  value = azurerm_network_watcher_flow_log.vnet_fl.name
}

output "storage_account_name" {
  value = azurerm_storage_account.flowlogs.name
}

output "log_analytics_workspace_name" {
  value = azurerm_log_analytics_workspace.ta.name
}

output "verify_cli_command" {
  value = "az network watcher flow-log show --location ${var.location} --name ${azurerm_network_watcher_flow_log.vnet_fl.name}"
}
