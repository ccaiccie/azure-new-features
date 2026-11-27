variable "location" {
  description = "Azure region that supports Application Gateway for Containers (e.g., eastus2, northeurope, westeurope, westus2)."
  type        = string
  default     = "eastus2"
}

variable "resource_group_name" {
  description = "Name of the disposable resource group for this lab."
  type        = string
  default     = "rg-agfc-lab-disposable"
}

variable "prefix" {
  description = "Short lowercase prefix used for naming lab resources."
  type        = string
  default     = "agfclab"
}

variable "vnet_address_space" {
  description = "Address space for the lab virtual network."
  type        = string
  default     = "10.20.0.0/16"
}

variable "aks_subnet_prefix" {
  description = "Subnet CIDR for AKS nodes and Azure CNI pods."
  type        = string
  default     = "10.20.1.0/24"
}

variable "alb_subnet_prefix" {
  description = "Delegated subnet CIDR for Application Gateway for Containers association (minimum /24, at least 256 addresses)."
  type        = string
  default     = "10.20.2.0/24"
}

variable "aks_node_count" {
  description = "Number of nodes in the default AKS system node pool."
  type        = number
  default     = 2
}

variable "aks_node_vm_size" {
  description = "VM size for AKS nodes."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "alb_controller_namespace" {
  description = "Kubernetes namespace where ALB Controller will be installed."
  type        = string
  default     = "azure-alb-system"
}

variable "tags" {
  description = "Tags applied to lab resources."
  type        = map(string)
  default = {
    environment = "lab"
    workload    = "agfc-demo"
    managed_by  = "terraform"
  }
}
