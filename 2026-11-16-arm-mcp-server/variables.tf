variable "resource_group_name" {
  type        = string
  description = "Resource group for the lab network."
  default     = "rg-arm-mcp-lab"
}

variable "location" {
  type        = string
  description = "Azure region."
  default     = "eastus"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for network resource names."
  default     = "armmcp"
}

variable "vnet_cidr" {
  type        = string
  description = "Address space of the lab virtual network."
  default     = "10.80.0.0/16"
}

variable "subnet_cidr" {
  type        = string
  description = "Address prefix of the workload subnet."
  default     = "10.80.1.0/24"
}

variable "management_prefix" {
  type        = string
  description = "Source prefix allowed to SSH after you deploy the Bicep change. Default is a documentation range; replace it with your real management prefix."
  default     = "192.0.2.0/24"
}
