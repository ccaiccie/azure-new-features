variable "resource_group_name" {
  type        = string
  description = "Name of the lab resource group."
  default     = "rg-private-link-lab"
}

variable "location" {
  type        = string
  description = "Azure region for the lab."
  default     = "eastus"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names."
  default     = "pllab"
}

variable "vnet_cidr" {
  type        = string
  description = "Virtual network IPv4 address space."
  default     = "10.60.0.0/16"
}

variable "endpoint_subnet_cidr" {
  type        = string
  description = "Subnet that holds private endpoints."
  default     = "10.60.1.0/24"
}

variable "service_subnet_cidr" {
  type        = string
  description = "Subnet that holds the internal load balancer and Private Link Service."
  default     = "10.60.2.0/24"
}

variable "ip_version_type" {
  type        = string
  description = "IP version for the storage private endpoint. azurerm 5.14.0 accepts IPv4, IPv6, or DualStack. Private Link over IPv6 is a public preview in limited regions. Keep IPv4 unless you have preview access and a dual-stack virtual network; DualStack also requires private_endpoint_vnet_policies = Basic on the virtual network and private_endpoint_network_policies = RouteTableEnabled on the subnet."
  default     = "IPv4"

  validation {
    condition     = contains(["IPv4", "IPv6", "DualStack"], var.ip_version_type)
    error_message = "ip_version_type must be IPv4, IPv6, or DualStack."
  }
}
