variable "subscription_id" {
  type        = string
  description = "Subscription for the lab."
}

variable "location" {
  type        = string
  description = "Region for the lab. Network security perimeter is GA in all Azure public regions."
  default     = "eastus2"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the lab resource group."
  default     = "rg-nsp-lab"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names (keep it short: member names over 44 characters cause association issues)."
  default     = "nsplab"
}

variable "allowed_inbound_prefixes" {
  type        = list(string)
  description = "Public address prefixes allowed inbound, for example your office or home egress IP as x.x.x.x/32."
  default     = ["203.0.113.10/32"]
}

variable "allowed_outbound_fqdns" {
  type        = list(string)
  description = "Destinations the members may send data to (outbound rules are FQDN only)."
  default     = ["api.contoso.example"]
}

variable "storage_access_mode" {
  type        = string
  description = "Access mode for the storage account association. Learning is the API name of Transition mode."
  default     = "Learning"

  validation {
    condition     = contains(["Learning", "Enforced", "Audit"], var.storage_access_mode)
    error_message = "Use Learning (Transition), Enforced or Audit."
  }
}

variable "key_vault_access_mode" {
  type        = string
  description = "Access mode for the key vault association."
  default     = "Enforced"

  validation {
    condition     = contains(["Learning", "Enforced", "Audit"], var.key_vault_access_mode)
    error_message = "Use Learning (Transition), Enforced or Audit."
  }
}
