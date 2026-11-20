variable "subscription_id" {
  type        = string
  description = "Azure subscription ID used by the azurerm provider."
}

variable "location" {
  type        = string
  description = "Azure region for lab resources. The official virtual-network tutorial for ACI sandboxes uses centralus. Serverless sandboxes and Agent Grid are previews and are not available in every region. Confirm current region lists in the Microsoft Learn articles linked in the README before you apply."
  default     = "centralus"
}

variable "name_prefix" {
  type        = string
  description = "Short prefix for lab resource names. Keep this short: the storage account name is st + this prefix + unique_suffix and must be 3-24 characters."
  default     = "agntai"

  validation {
    condition     = can(regex("^[a-z0-9]{3,10}$", var.name_prefix))
    error_message = "name_prefix must be 3-10 lowercase letters or numbers."
  }
}

variable "resource_group_name" {
  type        = string
  description = "Resource group to create for this lab."
  default     = "rg-agentic-ai-infra-lab"
}

variable "unique_suffix" {
  type        = string
  description = "Short lowercase alphanumeric suffix so the storage account name is globally unique."

  validation {
    condition     = can(regex("^[a-z0-9]{3,8}$", var.unique_suffix))
    error_message = "unique_suffix must be 3-8 lowercase letters or numbers."
  }
}

variable "vnet_cidr" {
  type        = string
  description = "Illustrative IPv4 address space for the lab virtual network. This is a teaching value, not a production recommendation."
  default     = "10.64.0.0/16"
}

variable "sandbox_subnet_cidr" {
  type        = string
  description = "Sandbox subnet for an AI agents group. Official docs: each sandbox uses one IP, and the group network profile cannot be changed after create. A /24 is enough for a small lab; Microsoft's tutorial uses a /21 only as a size illustration. Add the official Microsoft.ContainerInstance/AIAgentsGroups delegation after apply; azurerm 5.14.0 cannot set that name."
  default     = "10.64.0.0/24"
}

variable "private_endpoint_subnet_cidr" {
  type        = string
  description = "Subnet that holds the storage private endpoint."
  default     = "10.64.8.0/24"
}

variable "log_retention_days" {
  type        = number
  description = "Log Analytics retention in days. Keep this low for a short-lived lab."
  default     = 30

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 90
    error_message = "log_retention_days must be between 30 and 90 for this lab."
  }
}
