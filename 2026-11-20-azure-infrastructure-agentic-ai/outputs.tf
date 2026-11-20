output "resource_group_name" {
  value       = azurerm_resource_group.lab.name
  description = "Lab resource group."
}

output "virtual_network_name" {
  value       = azurerm_virtual_network.lab.name
  description = "Lab virtual network."
}

output "sandbox_subnet_id" {
  value       = azurerm_subnet.sandbox.id
  description = "Delegated subnet ID to use in properties.networkProfile.subnets when you create the AI agents group with ARM or REST."
}

output "nat_gateway_name" {
  value       = azurerm_nat_gateway.lab.name
  description = "NAT gateway associated with the sandbox subnet."
}

output "nat_public_ip" {
  value       = azurerm_public_ip.nat.ip_address
  description = "Public IP used by the NAT gateway for sandbox egress."
}

output "group_identity_id" {
  value       = azurerm_user_assigned_identity.group.id
  description = "User-assigned managed identity resource ID for the AI agents group."
}

output "group_identity_principal_id" {
  value       = azurerm_user_assigned_identity.group.principal_id
  description = "Principal ID to use as the federated-credential subject when you create an Entra Agent ID blueprint, as in the official agent-identity tutorial."
}

output "storage_account_name" {
  value       = azurerm_storage_account.artifacts.name
  description = "Private storage account for artifacts. Grant data-plane roles to an Entra Agent ID, not only to the group managed identity."
}

output "storage_blob_private_endpoint_id" {
  value       = azurerm_private_endpoint.blob.id
  description = "Private endpoint for blob."
}

output "log_analytics_workspace_id" {
  value       = azurerm_log_analytics_workspace.lab.id
  description = "Log Analytics workspace ID."
}
