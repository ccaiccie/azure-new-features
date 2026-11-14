variable "resource_group_name" {
  type        = string
  description = "Name of the lab resource group."
  default     = "rg-appgw-routing-lab"
}

variable "location" {
  type        = string
  description = "Azure region for Application Gateway."
  default     = "eastus"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names."
  default     = "appgwlab"
}

variable "vnet_cidr" {
  type        = string
  description = "Virtual network IPv4 address space."
  default     = "10.70.0.0/16"
}

variable "subnet_cidr" {
  type        = string
  description = "Subnet for Application Gateway. Standard_v2 needs a /24 or larger in most designs; a /26 is the documented minimum in some cases."
  default     = "10.70.1.0/24"
}

variable "app_backend_fqdn" {
  type        = string
  description = "FQDN used as the default and /app/* backend. Replace with your own backend if you have one."
  default     = "www.example.com"
}

variable "api_backend_fqdn" {
  type        = string
  description = "FQDN used as the /api/* backend."
  default     = "www.example.com"
}
