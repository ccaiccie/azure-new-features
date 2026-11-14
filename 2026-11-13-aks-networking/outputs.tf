output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "fleet_manager_id" {
  value = azurerm_kubernetes_fleet_manager.lab.id
}

output "cluster_name" {
  value = var.create_cluster ? azurerm_kubernetes_cluster.lab[0].name : null
}

output "cluster_fqdn" {
  value = var.create_cluster ? azurerm_kubernetes_cluster.lab[0].fqdn : null
}

output "kube_config" {
  value     = var.create_cluster ? azurerm_kubernetes_cluster.lab[0].kube_config_raw : null
  sensitive = true
}
