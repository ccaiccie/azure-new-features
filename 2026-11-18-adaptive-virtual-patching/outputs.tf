output "vm_public_ip" {
  description = "Public IP of the single Linux VM (nginx on 80, demo service on the mitigation port)."
  value       = azurerm_public_ip.vm.ip_address
}

output "lb_public_ip" {
  description = "Public IP of the Standard Load Balancer in front of the scale set."
  value       = azurerm_public_ip.lb.ip_address
}

output "vm_id" {
  description = "Resource ID of the Linux VM (a candidate protected resource)."
  value       = azurerm_linux_virtual_machine.web.id
}

output "vmss_id" {
  description = "Resource ID of the Linux scale set (a candidate protected resource)."
  value       = azurerm_linux_virtual_machine_scale_set.web.id
}

output "temporary_mitigation_rule" {
  description = "Name of the temporary NSG deny rule, or null when rolled back."
  value       = try(azurerm_network_security_rule.temporary_mitigation[0].name, null)
}

output "test_commands" {
  description = "Quick reachability tests from your own IP."
  value = [
    "curl -s http://${azurerm_public_ip.vm.ip_address}:${var.mitigation_port}",
    "curl -s http://${azurerm_public_ip.lb.ip_address}:${var.mitigation_port}",
  ]
}
