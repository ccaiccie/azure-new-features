variable "subscription_id" {
  description = "Azure subscription ID for the lab."
  type        = string
}

variable "location" {
  description = "Azure region for the hub VNet and Azure Firewall Premium."
  type        = string
  default     = "eastus2"
}

variable "prefix" {
  description = "Short prefix for lab resource names."
  type        = string
  default     = "azfwidps"
}

variable "idps_mode" {
  description = "Azure Firewall Premium IDPS mode: Off, Alert, or Deny (Alert and Deny)."
  type        = string
  default     = "Alert"

  validation {
    condition     = contains(["Off", "Alert", "Deny"], var.idps_mode)
    error_message = "idps_mode must be Off, Alert, or Deny."
  }
}

variable "threat_intel_mode" {
  description = "Threat intelligence filtering mode: Off, Alert, or Deny."
  type        = string
  default     = "Alert"

  validation {
    condition     = contains(["Off", "Alert", "Deny"], var.threat_intel_mode)
    error_message = "threat_intel_mode must be Off, Alert, or Deny."
  }
}

variable "idps_private_ranges" {
  description = "Private IP ranges used by IDPS to classify Inbound, Outbound, and Internal (East-West) traffic."
  type        = list(string)
  default     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
}

variable "idps_signature_overrides" {
  description = "Optional map of Signature ID => mode (Off, Alert, or Deny) for false-positive tuning."
  type        = map(string)
  default     = {}
}
