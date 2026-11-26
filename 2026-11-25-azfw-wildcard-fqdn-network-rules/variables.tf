variable "resource_group_name" {
  description = "Name of the Azure resource group for the lab."
  type        = string
  default     = "rg-azfw-wildcard-lab"
}

variable "location" {
  description = "Azure region for the lab. Official docs currently list uksouth, westcentralus, and eastasia for wildcard domains in network rules."
  type        = string
  default     = "uksouth"

  validation {
    condition     = contains(["uksouth", "westcentralus", "eastasia"], var.location)
    error_message = "Wildcard FQDNs in Azure Firewall network rules are currently documented as supported in uksouth, westcentralus, and eastasia."
  }
}

variable "firewall_sku" {
  description = "Azure Firewall SKU tier. DNS proxy is supported on Standard and Premium only (not Basic)."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.firewall_sku)
    error_message = "firewall_sku must be Standard or Premium because Azure Firewall Basic does not support DNS proxy."
  }
}

variable "custom_dns_servers" {
  description = "Optional list of up to 15 custom upstream DNS servers. Leave empty to use default Azure DNS."
  type        = list(string)
  default     = []
}

variable "wildcard_ntp_fqdn" {
  description = "Wildcard FQDN allowed for UDP/123 (NTP) testing."
  type        = string
  default     = "*.pool.ntp.org"
}

variable "wildcard_app_fqdn" {
  description = "Wildcard FQDN allowed for TCP testing (replace with your own domain family)."
  type        = string
  default     = "*.contoso.com"
}

variable "log_analytics_workspace_name" {
  description = "Globally unique name for the Log Analytics workspace."
  type        = string
  default     = "law-azfw-wildcard-lab-01"
}

variable "vm_size" {
  description = "Azure VM size for the spoke test VM."
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Admin username for the spoke Linux VM."
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH public key string for the spoke Linux VM."
  type        = string
}
