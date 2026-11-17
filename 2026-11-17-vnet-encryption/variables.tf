variable "subscription_id" {
  type        = string
  description = "Subscription for the lab."
}

variable "location" {
  type        = string
  description = "Region for the lab. Virtual Network encryption is GA in all public regions."
  default     = "eastus2"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the lab resource group."
  default     = "rg-vnetenc-lab"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names."
  default     = "vnetenc"
}

variable "enforcement" {
  type        = string
  description = "Encryption enforcement. AllowUnencrypted is the only value supported at GA."
  default     = "AllowUnencrypted"

  validation {
    condition     = contains(["AllowUnencrypted", "DropUnencrypted"], var.enforcement)
    error_message = "Use AllowUnencrypted (GA) or DropUnencrypted (future)."
  }
}

variable "create_vms" {
  type        = bool
  description = "Create one Linux VM per VNet to generate traffic."
  default     = true
}

variable "vm_size" {
  type        = string
  description = "VM size. Must support Virtual Network encryption and Accelerated Networking (all v5+ D and E series)."
  default     = "Standard_D2s_v5"
}

variable "admin_username" {
  type        = string
  description = "Admin user for the VMs."
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  type        = string
  description = "SSH public key for the VMs (contents, not a path)."
  default     = ""
}

variable "network_watcher_name" {
  type        = string
  description = "Existing Network Watcher in the region (Azure usually creates NetworkWatcher_<region> in NetworkWatcherRG)."
  default     = "NetworkWatcher_eastus2"
}

variable "network_watcher_resource_group" {
  type        = string
  description = "Resource group of the existing Network Watcher."
  default     = "NetworkWatcherRG"
}

variable "flow_log_retention_days" {
  type        = number
  description = "Days to keep VNet flow logs."
  default     = 7
}
