variable "resource_group_name" {
  type        = string
  description = "Name of the lab resource group."
  default     = "rg-routeserver-dualstack-lab"
}

variable "location" {
  type        = string
  description = "Azure region. Dual-stack Route Server is public preview and only documented in selected regions. Default is westcentralus, which is on that list. Your subscription also needs preview access."
  default     = "westcentralus"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names."
  default     = "rsdual"
}

variable "ipv4_address_space" {
  type        = string
  description = "Virtual network IPv4 address space."
  default     = "10.0.0.0/16"
}

variable "ipv6_address_space" {
  type        = string
  description = "Virtual network IPv6 address space."
  default     = "fd00:0:100::/48"
}

variable "route_server_ipv4_prefix" {
  type        = string
  description = "IPv4 prefix for RouteServerSubnet. Must be at least /27."
  default     = "10.0.1.0/26"
}

variable "route_server_ipv6_prefix" {
  type        = string
  description = "IPv6 /64 prefix for RouteServerSubnet, from the virtual network IPv6 space."
  default     = "fd00:0:100:1::/64"
}

variable "nva_ipv4_prefix" {
  type        = string
  description = "IPv4 prefix for a second subnet you can use later for an NVA. This lab does not create an NVA."
  default     = "10.0.0.0/24"
}

variable "nva_ipv6_prefix" {
  type        = string
  description = "IPv6 /64 prefix for the NVA subnet."
  default     = "fd00:0:100:2::/64"
}

variable "branch_to_branch_traffic_enabled" {
  type        = bool
  description = "Whether Route Server exchanges routes between ExpressRoute and VPN gateways (branch-to-branch)."
  default     = false
}
