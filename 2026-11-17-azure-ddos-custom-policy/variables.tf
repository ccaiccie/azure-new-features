variable "location" {
  type        = string
  description = "Azure region for the lab resources."
  default     = "eastus"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the lab resource group. Use a dedicated group so destroy is straightforward."
}

variable "name_prefix" {
  type        = string
  description = "Short prefix for resource names."
  default     = "ddoslab"
}

variable "vnet_cidr" {
  type        = string
  description = "Address space for the lab virtual network. Illustrative only."
  default     = "10.80.0.0/16"
}

variable "subnet_cidr" {
  type        = string
  description = "Address prefix for the single lab subnet. Illustrative only."
  default     = "10.80.1.0/24"
}

variable "tcp_syn_threshold_pps" {
  type        = number
  description = "Inbound TCP SYN detection threshold in packets per second. Valid range is 1,000 to 100,000. This is an example, not a recommended production value."
  default     = 20000

  validation {
    condition     = var.tcp_syn_threshold_pps >= 1000 && var.tcp_syn_threshold_pps <= 100000
    error_message = "tcp_syn_threshold_pps must be between 1,000 and 100,000."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to supported lab resources."
  default = {
    purpose = "ddos-custom-policy-lab"
    lesson  = "2026-11-17-azure-ddos-custom-policy"
  }
}
