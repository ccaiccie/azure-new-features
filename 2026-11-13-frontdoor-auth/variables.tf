variable "resource_group_name" {
  type        = string
  description = "Name of the lab resource group."
  default     = "rg-frontdoor-auth-lab"
}

variable "location" {
  type        = string
  description = "Azure region for the resource group. Front Door itself is a global resource."
  default     = "eastus"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for Front Door resource names. The endpoint name must be globally unique."
  default     = "fdauthlab"
}

variable "origin_host_name" {
  type        = string
  description = "Public origin hostname used for the lab. Replace with your own origin if you prefer."
  default     = "www.example.com"
}
