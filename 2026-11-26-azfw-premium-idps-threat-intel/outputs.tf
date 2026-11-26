output "resource_group_name" {
  description = "Lab Azure Resource Group name."
  value       = azurerm_resource_group.lab.name
}

output "firewall_private_ip" {
  description = "Private IP address of Azure Firewall Premium (use as UDR next hop for spoke VMs)."
  value       = azurerm_firewall.premium.ip_configuration[0].private_ip_address
}

output "firewall_policy_name" {
  description = "Azure Firewall Premium policy name."
  value       = azurerm_firewall_policy.premium.name
}

output "log_analytics_workspace_name" {
  description = "Log Analytics workspace receiving AZFWIdpsSignature and AZFWThreatIntel logs."
  value       = azurerm_log_analytics_workspace.fw.name
}
