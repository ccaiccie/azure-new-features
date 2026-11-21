variable "location" {
  description = "Azure region for the DDoS Network Protection lab resources."
  type        = string
  default     = "eastus2"
}

variable "resource_group_name" {
  description = "Name of the resource group."
  type        = string
  default     = "rg-ddos-network-protection-lab"
}

variable "prefix" {
  description = "Naming prefix for lab resources."
  type        = string
  default     = "nt-ddos"
}
