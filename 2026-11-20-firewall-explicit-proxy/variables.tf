variable "subscription_id" {
  type        = string
  description = "Azure subscription ID used by the azurerm provider. You need rights to create role assignments on the storage account."
}

variable "location" {
  type        = string
  description = "Azure region for every lab resource."
  default     = "eastus2"
}

variable "name_prefix" {
  type        = string
  description = "Short prefix for lab resource names (lowercase letters and digits only, it is also used for the storage account name)."
  default     = "fwexp"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group to create for this lab."
  default     = "rg-fwexp-lab"
}

variable "vnet_cidr" {
  type        = string
  description = "Address space for the lab virtual network."
  default     = "10.30.0.0/16"
}

variable "firewall_subnet_cidr" {
  type        = string
  description = "AzureFirewallSubnet prefix. Must be /26 or larger."
  default     = "10.30.0.0/26"
}

variable "client_subnet_cidr" {
  type        = string
  description = "Subnet for the test client VM. No route table is attached to it on purpose: explicit proxy does not need a UDR."
  default     = "10.30.1.0/24"
}

variable "firewall_private_ip" {
  type        = string
  description = "Private IP the PAC file points clients at. Azure assigns the first usable address of AzureFirewallSubnet (the fourth address, for example 10.30.0.4). A check block fails the apply output if the real address differs, so you can correct this value and re-apply."
  default     = "10.30.0.4"
}

variable "firewall_sku_tier" {
  type        = string
  description = "Firewall and policy tier. Explicit proxy is supported on Standard and Premium."
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.firewall_sku_tier)
    error_message = "Explicit proxy is supported on the Standard and Premium tiers only."
  }
}

variable "proxy_http_port" {
  type        = number
  description = "Explicit proxy listener port. One HTTP port serves both HTTP and HTTPS destinations. Valid range is up to 64000."
  default     = 8080

  validation {
    condition     = var.proxy_http_port >= 1 && var.proxy_http_port <= 64000
    error_message = "The port must be between 1 and 64000."
  }
}

variable "proxy_https_port" {
  type        = number
  description = "Legacy (preview-era) separate HTTPS listener port. Leave null: the generally available design uses the single HTTP port for HTTPS destinations too. The azurerm provider still exposes the argument; if you set it, it must differ from the HTTP port."
  default     = null
}

variable "pac_file_port" {
  type        = number
  description = "Port on which the firewall serves the PAC file to clients. Must differ from the proxy port."
  default     = 8090
}

variable "allowed_fqdns" {
  type        = list(string)
  description = "Destinations the application rule allows for proxied clients."
  default     = ["www.microsoft.com", "learn.microsoft.com"]
}

variable "create_test_vm" {
  type        = bool
  description = "Create a small Ubuntu client VM (no public IP) for the curl tests. Set false to save cost and use your own client."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource."
  default = {
    lab     = "firewall-explicit-proxy"
    managed = "terraform"
  }
}

variable "sas_start" {
  type        = string
  description = "Start time of the read-only SAS on the PAC container (RFC 3339). Fixed values keep plans free of changes."
  default     = "2026-11-01T00:00:00Z"
}

variable "sas_expiry" {
  type        = string
  description = "Expiry of the SAS in the PAC file URL (RFC 3339). Renew it before it lapses and re-apply the policy."
  default     = "2027-11-01T00:00:00Z"
}
