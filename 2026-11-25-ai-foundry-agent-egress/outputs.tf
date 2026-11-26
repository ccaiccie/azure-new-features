output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "foundry_account_name" {
  value = azapi_resource.foundry_account.name
}

output "storage_account_name" {
  value = azurerm_storage_account.agent_data.name
}

output "isolation_mode" {
  value = var.isolation_mode
}

output "verify_commands" {
  value = <<-EOT
    az cognitiveservices account managed-network show --resource-group ${azurerm_resource_group.lab.name} --name ${azapi_resource.foundry_account.name}
    az cognitiveservices account managed-network outbound-rule list --resource-group ${azurerm_resource_group.lab.name} --name ${azapi_resource.foundry_account.name}
  EOT
}
