output "resource_group_name" {
  description = "Resource group name containing all lab resources."
  value       = azurerm_resource_group.lab.name
}

output "frontdoor_url" {
  description = "Public HTTPS entry point served by Azure Front Door Premium."
  value       = "https://${azurerm_cdn_frontdoor_endpoint.lab.host_name}"
}

output "origin_direct_url" {
  description = "Direct App Service hostname (public network access is disabled; direct requests should fail with 403)."
  value       = "https://${azurerm_linux_web_app.origin.default_hostname}"
}

output "web_app_name" {
  description = "Name of the private App Service origin."
  value       = azurerm_linux_web_app.origin.name
}

output "waf_policy_name" {
  description = "Name of the Front Door WAF policy."
  value       = azurerm_cdn_frontdoor_firewall_policy.lab.name
}

output "waf_mode" {
  description = "Current WAF policy mode (Detection or Prevention)."
  value       = azurerm_cdn_frontdoor_firewall_policy.lab.mode
}

output "log_analytics_workspace_name" {
  description = "Log Analytics workspace receiving Front Door WAF and Access logs."
  value       = azurerm_log_analytics_workspace.lab.name
}
