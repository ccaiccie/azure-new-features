variable "subscription_id" {
  type        = string
  description = "Azure subscription ID used by the azurerm provider."
}

variable "location" {
  type        = string
  description = "Azure region for every lab resource. During the AI Security public preview, the add-on itself is documented only in East Asia, UK South, and West Central US. Default is a preview region so you can enable the add-on in the portal after apply."
  default     = "westcentralus"
}

variable "name_prefix" {
  type        = string
  description = "Short prefix for lab resource names."
  default     = "fwaisec"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group to create for this lab."
  default     = "rg-fwaisec-lab"
}

variable "hub_cidr" {
  type        = string
  description = "Address space for the hub virtual network."
  default     = "10.10.0.0/16"
}

variable "hub_firewall_subnet_cidr" {
  type        = string
  description = "AzureFirewallSubnet prefix. Must be at least /26."
  default     = "10.10.0.0/24"
}

variable "spoke_cidr" {
  type        = string
  description = "Address space for the spoke virtual network."
  default     = "10.20.0.0/16"
}

variable "spoke_workload_subnet_cidr" {
  type        = string
  description = "Workload subnet in the spoke, associated with the default route to the firewall."
  default     = "10.20.1.0/24"
}

variable "intermediate_ca_pfx_path" {
  type        = string
  description = "Path to the password-less intermediate CA PFX (PKCS12) used for TLS inspection. Generate it first with ./cert.sh (see README)."
}

variable "inspected_destination_fqdns" {
  type        = list(string)
  description = "Destination FQDNs for the HTTPS application rule that has TLS termination enabled. Keep this tight. Do not add a wide network allow that would skip this rule."
  default = [
    "*.openai.azure.com",
    "*.cognitiveservices.azure.com",
    "www.microsoft.com"
  ]
}

variable "idps_mode" {
  type        = string
  description = "Azure Firewall Premium IDPS mode. Allowed values: Off, Alert, Deny."
  default     = "Alert"

  validation {
    condition     = contains(["Off", "Alert", "Deny"], var.idps_mode)
    error_message = "idps_mode must be Off, Alert, or Deny."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to lab resources."
  default = {
    purpose = "azure-new-features-lab"
    lesson  = "2026-11-19-firewall-ai-security"
  }
}
