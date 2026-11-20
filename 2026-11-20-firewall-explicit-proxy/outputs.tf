output "firewall_private_ip" {
  description = "Private IP that clients use as the proxy address."
  value       = azurerm_firewall.lab.ip_configuration[0].private_ip_address
}

output "proxy_endpoint" {
  description = "Manual proxy setting for browsers and tools (HTTP and HTTPS destinations use this one port)."
  value       = "http://${azurerm_firewall.lab.ip_configuration[0].private_ip_address}:${var.proxy_http_port}"
}

output "pac_blob_url" {
  description = "Blob URL of the PAC file (without the SAS token)."
  value       = azurerm_storage_blob.pac.url
}

output "explicit_proxy_settings" {
  description = "The explicit proxy settings applied to the policy."
  value = {
    enabled         = azurerm_firewall_policy.lab.explicit_proxy[0].enabled
    http_port       = azurerm_firewall_policy.lab.explicit_proxy[0].http_port
    enable_pac_file = azurerm_firewall_policy.lab.explicit_proxy[0].enable_pac_file
    pac_file_port   = azurerm_firewall_policy.lab.explicit_proxy[0].pac_file_port
  }
}

output "test_command" {
  description = "Runs curl on the client VM through the proxy: one allowed site and one site the application rule does not allow."
  value = var.create_test_vm ? join(" ", [
    "az vm run-command invoke",
    "--resource-group ${azurerm_resource_group.lab.name}",
    "--name ${azurerm_linux_virtual_machine.client[0].name}",
    "--command-id RunShellScript",
    "--scripts",
    "\"curl -s -o /dev/null -w 'allowed:%%{http_code}\\n' -x http://${azurerm_firewall.lab.ip_configuration[0].private_ip_address}:${var.proxy_http_port} https://www.microsoft.com; curl -s -o /dev/null -w 'blocked:%%{http_code}\\n' -x http://${azurerm_firewall.lab.ip_configuration[0].private_ip_address}:${var.proxy_http_port} https://www.example.org\"",
  ]) : "create_test_vm is false: run curl -x ${azurerm_firewall.lab.ip_configuration[0].private_ip_address}:${var.proxy_http_port} from your own client."
}

output "log_query" {
  description = "KQL for the AZFWApplicationRules table (needs diagnostic settings sending resource-specific logs to Log Analytics)."
  value       = "AZFWApplicationRules | where TimeGenerated > ago(30m) | project TimeGenerated, SourceIp, Fqdn, Action, Rule | order by TimeGenerated desc"
}
