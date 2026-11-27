variable "resource_group_name" {
  description = "Resource group name for the Azure VPN Gateway NAT and custom IPsec/IKE lab."
  type        = string
  default     = "rg-vpn-nat-ipsec-lab"
}

variable "location" {
  description = "Azure region for all lab resources."
  type        = string
  default     = "eastus"
}

variable "vpn_gateway_sku" {
  description = "VPN Gateway SKU. Lowest-cost officially supported SKU for NAT is VpnGw2 (VpnGw2~5 or VpnGw2AZ~5AZ)."
  type        = string
  default     = "VpnGw2"

  validation {
    condition     = contains(["VpnGw2", "VpnGw3", "VpnGw4", "VpnGw5", "VpnGw2AZ", "VpnGw3AZ", "VpnGw4AZ", "VpnGw5AZ"], var.vpn_gateway_sku)
    error_message = "Azure VPN Gateway NAT is officially supported only on VpnGw2~5 and VpnGw2AZ~5AZ."
  }
}

variable "vpn_gateway_generation" {
  description = "VPN Gateway generation (Generation2 is recommended for VpnGw2~5)."
  type        = string
  default     = "Generation2"
}

variable "vnet_cidr" {
  description = "Original Azure VNet CIDR (intentionally overlaps with Branch 1 and Branch 2)."
  type        = string
  default     = "10.0.1.0/24"
}

variable "workload_subnet_cidr" {
  description = "Workload subnet prefix inside the VNet."
  type        = string
  default     = "10.0.1.0/26"
}

variable "gateway_subnet_cidr" {
  description = "GatewaySubnet prefix inside the VNet (minimum /27 recommended)."
  type        = string
  default     = "10.0.1.224/27"
}

variable "vnet_translated_cidr" {
  description = "EgressSNAT External Mapping for the Azure VNet."
  type        = string
  default     = "192.168.1.0/24"
}

variable "branch1_peer_ip" {
  description = "Public IP of simulated Branch 1 VPN device (RFC 5737 TEST-NET-2 by default)."
  type        = string
  default     = "198.51.100.10"
}

variable "branch1_cidr" {
  description = "Original overlapping CIDR for Branch 1."
  type        = string
  default     = "10.0.1.0/24"
}

variable "branch1_translated_cidr" {
  description = "IngressSNAT External Mapping for Branch 1."
  type        = string
  default     = "192.168.2.0/24"
}

variable "branch2_peer_ip" {
  description = "Public IP of simulated Branch 2 VPN device (RFC 5737 TEST-NET-3 by default)."
  type        = string
  default     = "203.0.113.10"
}

variable "branch2_cidr" {
  description = "Original overlapping CIDR for Branch 2."
  type        = string
  default     = "10.0.1.0/24"
}

variable "branch2_translated_cidr" {
  description = "IngressSNAT External Mapping for Branch 2."
  type        = string
  default     = "192.168.3.0/24"
}

variable "vpn_shared_key" {
  description = "Pre-shared key for the IPsec S2S connections. Override via terraform.tfvars or TF_VAR_vpn_shared_key."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Common tags applied to all lab resources."
  type        = map(string)
  default = {
    environment = "lab"
    lesson      = "azure-vpn-gateway-nat-ipsec"
  }
}
