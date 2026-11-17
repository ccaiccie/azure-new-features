output "resource_group_name" {
  description = "Lab resource group."
  value       = azurerm_resource_group.lab.name
}

output "public_ip_id" {
  description = "Standard public IP attached to the load balancer frontend."
  value       = azurerm_public_ip.front.id
}

output "public_ip_address" {
  description = "Allocated frontend public IP address."
  value       = azurerm_public_ip.front.ip_address
}

output "load_balancer_name" {
  description = "Standard Load Balancer name."
  value       = azurerm_lb.lab.name
}

output "frontend_ip_configuration_id" {
  description = "Frontend IP configuration associated with the custom policy."
  value       = azurerm_lb.lab.frontend_ip_configuration[0].id
}

output "custom_policy_name" {
  description = "DDoS custom policy name."
  value       = "${var.name_prefix}-ddos-custom-policy"
}

output "tcp_syn_threshold_pps" {
  description = "Inbound TCP SYN threshold deployed by the lab, in packets per second."
  value       = var.tcp_syn_threshold_pps
}

output "show_policy_command" {
  description = "Azure CLI command to inspect the deployed custom policy."
  value       = "az network ddos-custom-policy show --resource-group ${azurerm_resource_group.lab.name} --name ${var.name_prefix}-ddos-custom-policy"
}
