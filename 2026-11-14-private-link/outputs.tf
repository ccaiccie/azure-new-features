output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "storage_account_name" {
  value = azurerm_storage_account.lab.name
}

output "blob_private_endpoint_id" {
  value = azurerm_private_endpoint.blob.id
}

output "blob_private_ip" {
  value = azurerm_private_endpoint.blob.private_service_connection[0].private_ip_address
}

output "private_link_service_id" {
  value = azurerm_private_link_service.lab.id
}

output "private_link_service_alias" {
  value = azurerm_private_link_service.lab.alias
}
