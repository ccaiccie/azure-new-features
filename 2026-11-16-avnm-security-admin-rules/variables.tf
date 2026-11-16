variable "resource_group_name" {
  type        = string
  description = "Name of the lab resource group."
  default     = "rg-avnm-security-admin-lab"
}

variable "location" {
  type        = string
  description = "Azure region for the lab and for the security admin deployment."
  default     = "eastus"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names."
  default     = "avnmlab"
}

variable "vnets" {
  type = map(object({
    cidr        = string
    subnet_cidr = string
  }))
  description = "Virtual networks that join the governed network group."
  default = {
    prod = { cidr = "10.60.0.0/16", subnet_cidr = "10.60.1.0/24" }
    dev  = { cidr = "10.61.0.0/16", subnet_cidr = "10.61.1.0/24" }
  }
}

variable "monitoring_prefix" {
  type        = string
  description = "Address range of the monitoring probes that must always reach 443."
  default     = "10.200.0.0/24"
}

variable "bastion_prefix" {
  type        = string
  description = "Address range of the management subnet allowed to use SSH."
  default     = "10.201.0.0/26"
}

variable "high_risk_ports" {
  type        = list(string)
  description = "Destination ports denied from the Internet."
  default     = ["22", "23", "135", "445", "3389", "5900"]
}
