variable "location" {
  description = "Azure region for all lab resources."
  type        = string
  default     = "eastus2"
}

variable "prefix" {
  description = "Short lowercase prefix used for naming resources."
  type        = string
  default     = "la-msmq-lab"
}

variable "vnet_address_space" {
  description = "CIDR block for the lab virtual network."
  type        = string
  default     = "10.42.0.0/16"
}

variable "integration_subnet_prefix" {
  description = "Dedicated subnet CIDR delegated to Microsoft.Web/serverFarms for Logic Apps Standard VNet integration."
  type        = string
  default     = "10.42.1.0/24"
}

variable "broker_subnet_prefix" {
  description = "Private subnet CIDR hosting the Windows Server MSMQ Broker VM."
  type        = string
  default     = "10.42.2.0/24"
}

variable "bastion_subnet_prefix" {
  description = "Optional AzureBastionSubnet CIDR when enable_bastion is true."
  type        = string
  default     = "10.42.3.0/26"
}

variable "msmq_broker_port" {
  description = "TCP port the MSMQ Broker Windows service listens on (default 5050)."
  type        = number
  default     = 5050
}

variable "broker_vm_size" {
  description = "VM SKU for the customer-managed Windows Server MSMQ Broker host."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "broker_admin_username" {
  description = "Local administrator username for the Windows Server MSMQ Broker VM."
  type        = string
  default     = "msmqadmin"
}

variable "broker_admin_password" {
  description = "Local administrator password for the Windows Server MSMQ Broker VM. Supply via TF_VAR_broker_admin_password or terraform.tfvars."
  type        = string
  sensitive   = true
}

variable "private_dns_zone_name" {
  description = "Private DNS zone name linked to the VNet for private broker hostname resolution."
  type        = string
  default     = "msmq.internal.lab"
}

variable "enable_bastion" {
  description = "Set true to deploy Azure Bastion for private browser-based RDP access without a public IP on the broker VM."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags applied to lab resources."
  type        = map(string)
  default = {
    lab     = "2026-11-22-logic-apps-msmq-sql-hybrid"
    purpose = "msmq-private-network-path"
  }
}
