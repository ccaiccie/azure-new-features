output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "vm_name" {
  value = azurerm_linux_virtual_machine.vm.name
}

output "vm_private_ip" {
  value = azurerm_network_interface.vm.private_ip_address
}

output "resolver_policy_id" {
  value = azapi_resource.policy.id
}

output "rules" {
  value = {
    "100 allow-exceptions" = var.allowed_domains
    "200 block-list"       = var.blocked_domains
    "300 alert-watchlist"  = var.watched_domains
    "400 threat-intel"     = "AzureDnsThreatIntel (${var.threat_intel_action})"
  }
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.dns.workspace_id
}

output "test_command" {
  value = "az vm run-command invoke -g ${azurerm_resource_group.lab.name} -n ${azurerm_linux_virtual_machine.vm.name} --command-id RunShellScript --scripts 'for n in www.example.org example.org mail.example.org badsite.example.net example.com microsoft.com; do echo \"== $n\"; dig +noall +answer +comments $n | grep -E \"status|IN\"; done'"
}
