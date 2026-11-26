variable "subscription_id" {
  description = "Azure subscription ID where the lab resources will be deployed."
  type        = string
}

variable "location" {
  description = "Supported Foundry managed VNet region (e.g., eastus2, swedencentral, uksouth, westus3)."
  type        = string
  default     = "eastus2"
}

variable "prefix" {
  description = "Short lowercase alphanumeric prefix for globally unique resource names (3-10 chars)."
  type        = string
  default     = "fndrylab"
}

variable "isolation_mode" {
  description = "Managed VNet outbound mode: AllowOnlyApprovedOutbound or AllowInternetOutbound."
  type        = string
  default     = "AllowOnlyApprovedOutbound"

  validation {
    condition     = contains(["AllowOnlyApprovedOutbound", "AllowInternetOutbound"], var.isolation_mode)
    error_message = "isolation_mode must be AllowOnlyApprovedOutbound or AllowInternetOutbound."
  }
}

variable "firewall_sku" {
  description = "Managed Azure Firewall SKU when using AllowOnlyApprovedOutbound with FQDN rules: Basic or Standard. Cannot be changed after deployment."
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard"], var.firewall_sku)
    error_message = "firewall_sku must be Basic or Standard."
  }
}

variable "enable_example_fqdn_rule" {
  description = "If true, creates an example FQDN outbound rule (*.openai.azure.com) which provisions the managed Azure Firewall."
  type        = bool
  default     = false
}
