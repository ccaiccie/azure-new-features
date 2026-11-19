variable "subscription_id" {
  type        = string
  description = "Subscription for the lab."
}

variable "location" {
  type        = string
  description = "Region for the lab. The resolver policy, its domain lists and every linked VNet must be in this same region."
  default     = "eastus2"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the lab resource group."
  default     = "rg-dnspolicy-lab"
}

variable "name_prefix" {
  type        = string
  description = "Short prefix for resource names."
  default     = "dnspol"
}

variable "blocked_domains" {
  type        = list(string)
  description = "Domains the Block rule applies to. Use fully qualified names with a trailing dot. A domain also covers its subdomains."
  default     = ["example.org.", "badsite.example.net."]
}

variable "allowed_domains" {
  type        = list(string)
  description = "Domains the higher-priority Allow rule applies to (an exception carved out of the block list)."
  default     = ["www.example.org."]
}

variable "watched_domains" {
  type        = list(string)
  description = "Domains the Alert rule applies to: resolved normally, but logged with the Alert action."
  default     = ["example.com."]
}

variable "threat_intel_action" {
  type        = string
  description = "Action for the rule that uses the Microsoft managed threat intelligence list (AzureDnsThreatIntel). Start with Alert, move to Block."
  default     = "Alert"

  validation {
    condition     = contains(["Alert", "Block"], var.threat_intel_action)
    error_message = "Use Alert or Block."
  }
}

variable "vm_size" {
  type        = string
  description = "Size of the small Linux test VM used to run dig through Azure-provided DNS."
  default     = "Standard_B1s"
}
