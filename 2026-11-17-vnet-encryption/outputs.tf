output "vnet_encryption" {
  description = "Encryption enforcement per VNet."
  value       = { for k, v in azurerm_virtual_network.vnet : v.name => v.encryption[0].enforcement }
}

output "vm_private_ips" {
  description = "Private IPs of the test VMs (empty if create_vms = false)."
  value       = { for k, n in azurerm_network_interface.vm : k => n.private_ip_address }
}

output "flow_log_storage_account" {
  description = "Storage account that receives VNet flow logs (container insights-logs-flowlogflowevent)."
  value       = azurerm_storage_account.flowlogs.name
}
