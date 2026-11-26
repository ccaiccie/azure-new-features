variable "subscription_id" {
  description = "Azure subscription ID for the lab VNet, connector host, and private target."
  type        = string
}

variable "location" {
  description = "Azure region for lab resources."
  type        = string
  default     = "eastus2"
}

variable "prefix" {
  description = "Short prefix for lab resource names."
  type        = string
  default     = "gsalab"
}

variable "admin_username" {
  description = "Local administrator username for lab VMs."
  type        = string
  default     = "labadmin"
}

variable "admin_password" {
  description = "Strong password for lab VMs (supply via terraform.tfvars or TF_VAR_admin_password; never commit)."
  type        = string
  sensitive   = true
}
