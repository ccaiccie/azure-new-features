output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "location" {
  value = azurerm_resource_group.lab.location
}

output "ddos_protection_plan_id" {
  value = azurerm_network_ddos_protection_plan.lab.id
}

output "virtual_network_id" {
  value = azurerm_virtual_network.lab.id
}

output "public_ip_id" {
  description = "Scope this resource in Azure Monitor Metrics and in the metric alerts."
  value       = azurerm_public_ip.front.id
}

output "public_ip_name" {
  value = azurerm_public_ip.front.name
}

output "public_ip_address" {
  value = azurerm_public_ip.front.ip_address
}

output "load_balancer_id" {
  value = azurerm_lb.lab.id
}

output "log_analytics_workspace_id" {
  description = "Optional. Platform peacetime metrics do not require Log Analytics. This workspace receives diagnostic logs and exported metrics."
  value       = azurerm_log_analytics_workspace.lab.id
}

output "action_group_id" {
  value = azurerm_monitor_action_group.lab.id
}

output "under_attack_alert_id" {
  value = azurerm_monitor_metric_alert.under_attack.id
}

output "traffic_alert_ids" {
  value = {
    tcp_packets     = azurerm_monitor_metric_alert.tcp_packets.id
    syn_packets     = azurerm_monitor_metric_alert.syn_packets.id
    inbound_packets = azurerm_monitor_metric_alert.inbound_packets.id
  }
}

output "custom_policy_note" {
  value = "hashicorp/azurerm 5.14.0 has no native azurerm_network_ddos_custom_policy resource (provider PRs 33232/33233 were still open when this lab was written). If you want a fixed TCP, UDP, or TCP SYN threshold, use the portal, Azure CLI, or an ARM template after you have a peacetime baseline. See the earlier lab 2026-11-17-azure-ddos-custom-policy and this README."
}
