variable "resource_group_name" {
  description = "Name of the Azure resource group for the StandardV2 NAT Gateway lab."
  type        = string
  default     = "rg-natgw-v2-lab"
}

variable "location" {
  description = "Azure region that supports StandardV2 NAT Gateway (do not use Canada East, India South Central, Sweden South, or West India)."
  type        = string
  default     = "eastus"
}

variable "prefix" {
  description = "Naming prefix for lab resources."
  type        = string
  default     = "natv2lab"
}

variable "vnet_ipv4_cidr" {
  description = "IPv4 address space for the lab VNet."
  type        = string
  default     = "10.40.0.0/16"
}

variable "vnet_ipv6_cidr" {
  description = "IPv6 address space for the lab VNet."
  type        = string
  default     = "fd00:40::/48"
}

variable "subnet_ipv4_cidr" {
  description = "IPv4 address prefix for the private workload subnet."
  type        = string
  default     = "10.40.1.0/24"
}

variable "subnet_ipv6_cidr" {
  description = "IPv6 address prefix for the private workload subnet."
  type        = string
  default     = "fd00:40:1::/64"
}

variable "idle_timeout_in_minutes" {
  description = "TCP idle timeout in minutes (4 to 120; default 4)."
  type        = number
  default     = 4
}

variable "vm_size" {
  description = "Size of the small Linux test VM."
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Admin username for the Linux test VM."
  type        = string
  default     = "labadmin"
}

variable "ssh_public_key_path" {
  description = "Local path to an SSH public key file for the Linux test VM."
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "tags" {
  description = "Tags applied to all lab resources."
  type        = map(string)
  default = {
    lab = "azure-nat-gateway-standardv2"
  }
}
