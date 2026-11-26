variable "resource_group_name" {
  description = "Name of the Azure resource group for the API Management networking lab."
  type        = string
  default     = "rg-apim-networking-lab"
}

variable "location" {
  description = "Azure region for all lab resources."
  type        = string
  default     = "eastus2"
}

variable "apim_name" {
  description = "Globally unique name for the Azure API Management instance."
  type        = string
}

variable "publisher_name" {
  description = "Publisher organization name for Azure API Management."
  type        = string
  default     = "Network Technician Lab"
}

variable "publisher_email" {
  description = "Publisher email address for Azure API Management."
  type        = string
}

variable "apim_sku_name" {
  description = "API Management SKU. Developer_1 is the lowest-cost tier that officially supports internal VNet injection."
  type        = string
  default     = "Developer_1"

  validation {
    condition     = can(regex("^(Developer_1|Premium_[0-9]+)$", var.apim_sku_name))
    error_message = "Classic internal VNet injection is officially supported only on Developer or Premium tiers."
  }
}

variable "vnet_address_space" {
  description = "CIDR address space for the lab virtual network."
  type        = list(string)
  default     = ["10.20.0.0/16"]
}

variable "appgw_subnet_prefix" {
  description = "CIDR prefix for the Application Gateway subnet."
  type        = string
  default     = "10.20.1.0/24"
}

variable "apim_subnet_prefix" {
  description = "CIDR prefix for the API Management internal VNet subnet (minimum /29; /24 leaves room for scaling)."
  type        = string
  default     = "10.20.2.0/24"
}

variable "backend_subnet_prefix" {
  description = "CIDR prefix for private backend workloads and test VMs."
  type        = string
  default     = "10.20.3.0/24"
}

variable "appgw_waf_mode" {
  description = "Application Gateway WAF mode (Detection for initial testing, Prevention for blocking)."
  type        = string
  default     = "Detection"
}
