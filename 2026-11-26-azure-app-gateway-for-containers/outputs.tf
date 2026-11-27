output "resource_group_name" {
  description = "Resource group containing the lab resources."
  value       = azurerm_resource_group.lab.name
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster."
  value       = azurerm_kubernetes_cluster.aks.name
}

output "alb_identity_client_id" {
  description = "Client ID of the user-assigned managed identity for ALB Controller Helm install."
  value       = azurerm_user_assigned_identity.alb.client_id
}

output "agfc_resource_id" {
  description = "ARM resource ID of the Application Gateway for Containers parent resource (for BYO Gateway annotation)."
  value       = azurerm_application_load_balancer.agfc.id
}

output "agfc_frontend_name" {
  description = "Name of the BYO Frontend resource."
  value       = azurerm_application_load_balancer_frontend.frontend.name
}

output "agfc_frontend_fqdn" {
  description = "Azure-generated FQDN of the Application Gateway for Containers Frontend."
  value       = azurerm_application_load_balancer_frontend.frontend.fully_qualified_domain_name
}
