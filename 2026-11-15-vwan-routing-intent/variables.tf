variable "resource_group_name" {
  type        = string
  description = "Name of the lab resource group."
  default     = "rg-vwan-intent-lab"
}

variable "location" {
  type        = string
  description = "Azure region for the Virtual WAN hub and firewall."
  default     = "eastus"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names."
  default     = "vwanlab"
}

variable "hub_address_prefix" {
  type        = string
  description = "Address prefix for the virtual hub. Must be a /24 or larger."
  default     = "10.80.0.0/24"
}

variable "spoke_cidr" {
  type        = string
  description = "Address space of the spoke virtual network."
  default     = "10.81.0.0/16"
}

variable "spoke_subnet_cidr" {
  type        = string
  description = "Workload subnet in the spoke virtual network."
  default     = "10.81.1.0/24"
}
