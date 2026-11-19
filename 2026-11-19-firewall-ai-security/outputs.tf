output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "location" {
  value = azurerm_resource_group.lab.location
}

output "hub_vnet_id" {
  value = azurerm_virtual_network.hub.id
}

output "spoke_vnet_id" {
  value = azurerm_virtual_network.spoke.id
}

output "spoke_workload_subnet_id" {
  value = azurerm_subnet.workload.id
}

output "firewall_id" {
  value = azurerm_firewall.lab.id
}

output "firewall_name" {
  value = azurerm_firewall.lab.name
}

output "firewall_private_ip" {
  description = "Next hop used by the spoke default route."
  value       = azurerm_firewall.lab.ip_configuration[0].private_ip_address
}

output "firewall_public_ip" {
  value = azurerm_public_ip.fw.ip_address
}

output "firewall_policy_id" {
  value = azurerm_firewall_policy.lab.id
}

output "firewall_policy_name" {
  value = azurerm_firewall_policy.lab.name
}

output "key_vault_name" {
  value = azurerm_key_vault.lab.name
}

output "tls_certificate_secret_id" {
  value = azurerm_key_vault_secret.intermediate_ca.id
}

output "log_analytics_workspace_id" {
  description = "Use this same workspace when you enable Policy Analytics in the portal, which Policy Advisor requires."
  value       = azurerm_log_analytics_workspace.lab.id
}

output "ai_security_addon_note" {
  value = "The azurerm provider has no argument for the AI Security add-on preview. After apply, enable the add-on on this Premium firewall in the Azure portal (expect downtime), then configure security profile groups on the policy. See the lab README."
}
