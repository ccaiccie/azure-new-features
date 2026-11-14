variable "resource_group_name" {
  type        = string
  description = "Name of the lab resource group."
  default     = "rg-aks-networking-lab"
}

variable "location" {
  type        = string
  description = "Azure region for the cluster and fleet."
  default     = "eastus"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names. Used as the AKS DNS prefix, so it must be unique in the region."
  default     = "aksnetlab"
}

variable "create_cluster" {
  type        = bool
  description = "Create a one-node AKS cluster with Cilium and Advanced Container Networking Services, and join it to the fleet. Set false to create only the fleet manager."
  default     = true
}

variable "vm_size" {
  type        = string
  description = "Size of the single system node. Use a size that supports Azure CNI Overlay with Cilium in your region."
  default     = "Standard_D2s_v3"
}

variable "vnet_cidr" {
  type        = string
  description = "Virtual network IPv4 address space."
  default     = "10.50.0.0/16"
}

variable "subnet_cidr" {
  type        = string
  description = "Subnet delegated to the AKS node pool."
  default     = "10.50.0.0/22"
}

variable "service_cidr" {
  type        = string
  description = "Kubernetes service CIDR. Must not overlap the virtual network."
  default     = "10.51.0.0/16"
}

variable "dns_service_ip" {
  type        = string
  description = "Cluster DNS service IP, inside service_cidr."
  default     = "10.51.0.10"
}
