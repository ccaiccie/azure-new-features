variable "location" {
  description = "Azure region supported by Packet Capture Insights (preview). Documented preview regions include eastus, eastus2, westus2, southcentralus, canadacentral, uksouth, northeurope, westeurope, centralindia, japaneast, southeastasia, australiaeast, southafricanorth."
  type        = string
  default     = "westus2"
}

variable "resource_group_name" {
  description = "Name of the resource group for the practice lab."
  type        = string
  default     = "rg-nw-pcap-insights-lab"
}

variable "admin_username" {
  description = "Admin SSH username for the two Ubuntu VMs."
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH public key content for authenticating to client-vm and web-vm."
  type        = string
}

variable "admin_source_cidr" {
  description = "Your public IP in CIDR notation (for example 203.0.113.10/32) allowed to SSH to client-vm."
  type        = string
}

variable "vm_size" {
  description = "Azure VM size for client-vm and web-vm."
  type        = string
  default     = "Standard_B2s"
}

variable "capture_time_limit_seconds" {
  description = "Maximum packet capture duration in seconds (default 600s for the lab; Azure default is 18000s)."
  type        = number
  default     = 600
}

variable "capture_total_bytes" {
  description = "Maximum total bytes for the packet capture session (default 104857600 = 100 MB; preview recommended limit is ~1 GB)."
  type        = number
  default     = 104857600
}
