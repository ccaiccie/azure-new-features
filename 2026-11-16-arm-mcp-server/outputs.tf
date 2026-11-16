output "resource_group_name" {
  description = "Resource group that is the deployment scope for the Bicep change."
  value       = azurerm_resource_group.lab.name
}

output "nsg_name" {
  description = "Network security group the Bicep file updates."
  value       = azurerm_network_security_group.lab.name
}

output "vnet_name" {
  description = "Lab virtual network."
  value       = azurerm_virtual_network.lab.name
}

output "management_prefix" {
  description = "Source prefix used by the Bicep allow rule."
  value       = var.management_prefix
}

output "what_if_command" {
  description = "Azure CLI what-if that previews the NSG rule change (same class of preview as the ARM MCP whatif_deployment tool)."
  value       = "az deployment group what-if --resource-group ${azurerm_resource_group.lab.name} --template-file nsg-management-ssh.bicep --parameters nsgName=${azurerm_network_security_group.lab.name} managementPrefix=${var.management_prefix}"
}

output "deploy_command" {
  description = "Azure CLI deployment that applies the reviewed Bicep change."
  value       = "az deployment group create --resource-group ${azurerm_resource_group.lab.name} --name nsg-management-ssh --template-file nsg-management-ssh.bicep --parameters nsgName=${azurerm_network_security_group.lab.name} managementPrefix=${var.management_prefix}"
}

output "verify_command" {
  description = "Inspect the live NSG after deployment (the CLI stand-in for get_resource)."
  value       = "az network nsg show --resource-group ${azurerm_resource_group.lab.name} --name ${azurerm_network_security_group.lab.name} --query securityRules"
}
