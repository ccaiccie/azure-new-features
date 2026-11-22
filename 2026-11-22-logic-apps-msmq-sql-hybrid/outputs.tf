output "resource_group_name" {
  description = "Name of the lab resource group."
  value       = azurerm_resource_group.lab.name
}

output "logic_app_name" {
  description = "Name of the Azure Logic Apps Standard resource."
  value       = azurerm_logic_app_standard.lab.name
}

output "logic_app_default_hostname" {
  description = "Default hostname of the Logic App Standard instance."
  value       = azurerm_logic_app_standard.lab.default_hostname
}

output "logic_app_kudu_url" {
  description = "Kudu (Advanced Tools) URL for running tcpping validation from the Logic App runtime."
  value       = "https://${azurerm_logic_app_standard.lab.name}.scm.azurewebsites.net"
}

output "integration_subnet_id" {
  description = "Subnet ID dedicated to Logic Apps Standard VNet integration."
  value       = azurerm_subnet.integration.id
}

output "broker_subnet_id" {
  description = "Subnet ID hosting the private Windows Server MSMQ Broker VM."
  value       = azurerm_subnet.broker.id
}

output "broker_private_ip" {
  description = "Private IP address of the Windows Server MSMQ Broker VM."
  value       = azurerm_network_interface.broker.private_ip_address
}

output "broker_private_fqdn" {
  description = "Private DNS name of the MSMQ Broker VM inside the VNet."
  value       = "${azurerm_private_dns_a_record.broker.name}.${azurerm_private_dns_zone.broker.name}"
}

output "kudu_tcpping_command" {
  description = "Command to run in the Logic App Kudu console after installing the MSMQ Broker service."
  value       = "tcpping ${azurerm_network_interface.broker.private_ip_address} ${var.msmq_broker_port}"
}
