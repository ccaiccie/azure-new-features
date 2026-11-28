variable "resource_group_name" {
  description = "Resource group name for the Azure API Management networking lab."
  type        = string
  default     = "rg-apim-net-v2"
}

variable "location" {
  description = "Azure region for all lab resources."
  type        = string
  default     = "eastus2"
}

variable "apim_name" {
  description = "Globally unique name for the Azure API Management instance (lowercase letters, numbers, hyphens)."
  type        = string
}

variable "publisher_name" {
  description = "Publisher organization name for Azure API Management."
  type        = string
  default     = "Network Technician Lab"
}

variable "publisher_email" {
  description = "Administrator email address for Azure API Management."
  type        = string
}

variable "apim_sku_name" {
  description = "APIM SKU. Developer_1 is the lowest-cost officially supported SKU for classic internal VNet injection."
  type        = string
  default     = "Developer_1"

  validation {
    condition     = can(regex("^(Developer_1|Premium_[1-9][0-9]*)$", var.apim_sku_name))
    error_message = "Classic internal VNet injection is supported only on Developer or Premium tiers."
  }
}

variable "appgw_capacity" {
  description = "Application Gateway WAF_v2 instance count (1 for non-production lab; 2+ recommended for production)."
  type        = number
  default     = 1
}

variable "tags" {
  description = "Common tags applied to all lab resources."
  type        = map(string)
  default = {
    lab         = "2026-11-27-azure-apim-networking-v2"
    environment = "nonprod-lab"
    managed_by  = "terraform"
  }
}
