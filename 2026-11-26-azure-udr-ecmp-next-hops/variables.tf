variable "subscription_id" {
  description = "Your Azure subscription ID (must have Microsoft.Network/AllowEcmpInRoute registered)."
  type        = string
}

variable "location" {
  description = "Azure region for the hub-and-spoke lab."
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of the resource group for this public-preview ECMP lab."
  type        = string
  default     = "rg-udr-ecmp-lab"
}

variable "admin_username" {
  description = "Linux administrator username for the lab VMs."
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Path to your local SSH public key file (for example, ~/.ssh/id_rsa.pub)."
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "vm_size" {
  description = "VM size for the spoke VMs and Linux NVA VMs."
  type        = string
  default     = "Standard_B2s"
}

variable "nva_count" {
  description = "Number of NVA VMs in the ECMP next-hop list (official overview limit: 2 to 16)."
  type        = number
  default     = 2

  validation {
    condition     = var.nva_count >= 2 && var.nva_count <= 16
    error_message = "Official Azure Virtual Network UDR ECMP guidance supports between 2 and 16 next-hop IP addresses per route."
  }
}
