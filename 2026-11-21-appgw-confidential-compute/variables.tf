variable "resource_group_name" {
  type        = string
  description = "Resource group for the lab."
  default     = "rg-appgw-cc-lab"
}

variable "location" {
  type        = string
  description = "Azure region. Default East US is on the Confidential Compute region list in the Learn article."
  default     = "eastus"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for lab resource names."
  default     = "appgwcc"
}

variable "vnet_cidr" {
  type        = string
  default     = "10.80.0.0/16"
}

variable "subnet_cidr" {
  type        = string
  default     = "10.80.1.0/24"
}

variable "backend_fqdn" {
  type        = string
  description = "Placeholder backend FQDN. This lab does not deploy a backend VM."
  default     = "www.example.com"
}
