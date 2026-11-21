output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "location" {
  value = azurerm_resource_group.lab.location
}

output "vnet_id" {
  value = azurerm_virtual_network.lab.id
}

output "aks_subnet_id" {
  value       = azurerm_subnet.aks.id
  description = "Use this value in SecurityPolicyAttachment.spec.aksWorkloadSubnets after you create the AKS cluster."
}

output "firewall_id" {
  value       = azurerm_firewall.lab.id
  description = "Use this Azure resource ID in SecurityPolicyAttachment.spec.firewallRef.id (existing-firewall path)."
}

output "firewall_private_ip" {
  value = azurerm_firewall.lab.ip_configuration[0].private_ip_address
}

output "firewall_policy_id" {
  value = azurerm_firewall_policy.lab.id
}

output "route_table_id" {
  value       = azurerm_route_table.aks.id
  description = "Associate this table with aks-subnet only after the firewall is running and before you attach a SecurityPolicy."
}

output "controller_identity_name" {
  value = azurerm_user_assigned_identity.controller.name
}

output "controller_identity_client_id" {
  value       = azurerm_user_assigned_identity.controller.client_id
  description = "Pass this to Helm as azfwController.podIdentity.clientID."
}

output "controller_identity_id" {
  value = azurerm_user_assigned_identity.controller.id
}
