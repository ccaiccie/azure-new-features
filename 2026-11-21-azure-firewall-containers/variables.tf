variable "resource_group_name" {
  type        = string
  description = "Resource group for this evaluation lab."
  default     = "rg-afc-lab"
}

variable "location" {
  type        = string
  description = "Must be an Azure Firewall for Containers preview region: centraluseuap, eastus2euap, westcentralus, eastasia, uksouth, or centralus."
  default     = "centralus"
}

variable "name_prefix" {
  type        = string
  description = "Prefix used to name lab resources."
  default     = "afc"
}

variable "vnet_cidr" {
  type        = string
  default     = "10.224.0.0/16"
}

variable "aks_subnet_cidr" {
  type        = string
  description = "Subnet reserved for a later AKS cluster using Azure CNI (not Overlay). This lab does not create the cluster."
  default     = "10.224.0.0/22"
}

variable "firewall_subnet_cidr" {
  type        = string
  description = "Must be used with the required name AzureFirewallSubnet."
  default     = "10.224.4.0/26"
}

variable "firewall_management_subnet_cidr" {
  type        = string
  description = "Must be used with the required name AzureFirewallManagementSubnet."
  default     = "10.224.4.64/26"
}

variable "tags" {
  type        = map(string)
  default     = { purpose = "azure-firewall-for-containers-lab" }
}
