variable "subscription_id" {
  type        = string
  description = "Subscription for the lab."
}

variable "location" {
  type        = string
  description = "Region for the lab. Check that Adaptive Virtual Patching (public preview) is offered in your region before onboarding."
  default     = "eastus2"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the lab resource group."
  default     = "rg-avp-lab"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names."
  default     = "avp"
}

variable "allowed_source_cidr" {
  type        = string
  description = "Your own public IP as a /32 (for example 203.0.113.10/32). Only this prefix may reach SSH and HTTP."
}

variable "vm_size" {
  type        = string
  description = "Size for the VM and the scale set instances."
  default     = "Standard_D2s_v5"
}

variable "vmss_instances" {
  type        = number
  description = "Number of scale set instances."
  default     = 2
}

variable "admin_username" {
  type        = string
  description = "Admin user for the Linux machines."
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  type        = string
  description = "SSH public key (contents, not a path)."
}

variable "temporary_mitigation_enabled" {
  type        = bool
  description = "Manual practice only: add a high-priority NSG deny rule for mitigation_port, a network-layer compensating control. Set back to false to roll it back after patching."
  default     = false
}

variable "mitigation_port" {
  type        = number
  description = "TCP port the temporary deny rule blocks (8080 is the demo 'vulnerable' service exposed by cloud-init)."
  default     = 8080
}
