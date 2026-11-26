variable "resource_group_name" {
  description = "Name of the resource group to create for this lab."
  type        = string
  default     = "rg-ddos-sku-lab"
}

variable "location" {
  description = "Azure region for the lab resources."
  type        = string
  default     = "eastus"
}

variable "public_ip_name" {
  description = "Name of the Standard SKU public IP address."
  type        = string
  default     = "pip-ddos-ip-lab"
}

variable "enable_ip_protection" {
  description = "Enable Azure DDoS IP Protection on the Standard public IP. BILLING WARNING: IP Protection bills per protected public IP (prorated hourly when active)."
  type        = bool
  default     = true
}

variable "enable_network_protection" {
  description = "OPTIONAL: Create an Azure DDoS Network Protection plan and link it to the lab virtual network. Defaults to false. BILLING WARNING: A DDoS Protection plan incurs a significant fixed monthly charge (prorated hourly) until the plan resource itself is deleted, not merely disabled on a virtual network."
  type        = bool
  default     = false
}

variable "vnet_name" {
  description = "Name of the lab virtual network."
  type        = string
  default     = "vnet-ddos-sku-lab"
}

variable "ddos_plan_name" {
  description = "Name of the optional Azure DDoS Network Protection plan (created only when enable_network_protection = true)."
  type        = string
  default     = "ddos-plan-sku-lab"
}

variable "enable_diagnostic_logging" {
  description = "Create a Log Analytics workspace and diagnostic setting on the public IP for DDoS logs and metrics."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags applied to lab resources."
  type        = map(string)
  default = {
    environment = "lab"
    lesson      = "azure-ddos-ip-vs-network-protection"
  }
}
