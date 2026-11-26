variable "resource_group_name" {
  description = "Resource group for the Front Door Premium WAF + Private Link lab."
  type        = string
  default     = "rg-afd-waf-pl-lab"
}

variable "location" {
  description = "Azure region with Availability Zone support for Front Door Private Link (for example eastus, westus2, westeurope)."
  type        = string
  default     = "eastus"
}

variable "project_prefix" {
  description = "Short lowercase prefix for resource names (3-10 alphanumeric characters)."
  type        = string
  default     = "afdpllab"
}

variable "waf_mode" {
  description = "Front Door WAF policy mode: Detection (log only) or Prevention (enforce blocks)."
  type        = string
  default     = "Detection"

  validation {
    condition     = contains(["Detection", "Prevention"], var.waf_mode)
    error_message = "waf_mode must be either Detection or Prevention."
  }
}

variable "app_service_sku" {
  description = "App Service Plan SKU that supports Private Endpoints (for example P0v3 or P1v3)."
  type        = string
  default     = "P0v3"
}

variable "blocked_test_header_value" {
  description = "Safe header value matched by the custom WAF rule on X-Lab-Test."
  type        = string
  default     = "block-me-lab"
}

variable "log_retention_days" {
  description = "Log Analytics workspace retention period in days."
  type        = number
  default     = 30
}
