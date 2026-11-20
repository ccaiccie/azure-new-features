variable "subscription_id" {
  type        = string
  description = "Azure subscription ID used by the azurerm provider."
}

variable "location" {
  type        = string
  description = "Azure region for every lab resource. Peacetime telemetry preview is documented for the Azure public cloud (IPv4 and IPv6), not sovereign clouds. Confirm current eligibility for your region before you apply."
  default     = "eastus"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the lab resource group. Use a dedicated group so destroy is straightforward."
  default     = "rg-ddos-peacetime-lab"
}

variable "name_prefix" {
  type        = string
  description = "Short prefix for lab resource names."
  default     = "ddospc"
}

variable "vnet_cidr" {
  type        = string
  description = "Address space for the lab virtual network. Illustrative only."
  default     = "10.90.0.0/16"
}

variable "subnet_cidr" {
  type        = string
  description = "Address prefix for the load-balancer subnet. Illustrative only."
  default     = "10.90.1.0/24"
}

variable "alert_email" {
  type        = string
  description = "Optional email added to the action group. Leave empty to create the action group without a receiver; alerts still target the group."
  default     = ""
}

variable "tcp_packets_alert_threshold_pps" {
  type        = number
  description = "PLACEHOLDER traffic-condition alert threshold for Inbound TCP packets DDoS (TCPPacketsInDDoS), in packets per second. This is an example, not a recommended production value. Replace it from peacetime baselines after apply."
  default     = 50000
}

variable "syn_packets_alert_threshold_pps" {
  type        = number
  description = "PLACEHOLDER traffic-condition alert threshold for Inbound SYN packets DDoS (SYNPacketsInDDoS), in packets per second. This is an example, not a recommended production value. Replace it from peacetime baselines after apply."
  default     = 5000
}

variable "inbound_packets_alert_threshold_pps" {
  type        = number
  description = "PLACEHOLDER traffic-condition alert threshold for Inbound packets DDoS (PacketsInDDoS), in packets per second. This is an example, not a recommended production value. Replace it from peacetime baselines after apply."
  default     = 50000
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to supported lab resources."
  default = {
    purpose = "azure-new-features-lab"
    lesson  = "2026-11-20-ddos-peacetime-telemetry"
  }
}
