output "perimeter_id" {
  description = "Network security perimeter ID."
  value       = azurerm_network_security_perimeter.nsp.id
}

output "storage_account_name" {
  description = "Storage account inside the perimeter."
  value       = azurerm_storage_account.data.name
}

output "key_vault_name" {
  description = "Key vault inside the perimeter."
  value       = azurerm_key_vault.kv.name
}

output "access_modes" {
  description = "Access mode per association (Learning = Transition mode)."
  value = {
    storage   = azurerm_network_security_perimeter_association.storage.access_mode
    key_vault = azurerm_network_security_perimeter_association.key_vault.access_mode
    logs      = azurerm_network_security_perimeter_association.logs.access_mode
  }
}

output "log_analytics_workspace_id" {
  description = "Workspace that receives the NSPAccessLogs table."
  value       = azurerm_log_analytics_workspace.logs.workspace_id
}
