variable "location" {
  type        = string
  default     = "westus2"
  description = "Azure region that supports Azure Virtual Network Manager connected groups."
}

variable "resource_group_name_prefix" {
  type        = string
  default     = "rg-avnm-conn-lab"
  description = "Prefix for the lab resource group name."
}

variable "topology_mode" {
  type        = string
  default     = "mesh"
  description = "Connectivity topology to create and deploy: 'mesh' or 'hub_and_spoke'."

  validation {
    condition     = contains(["mesh", "hub_and_spoke"], var.topology_mode)
    error_message = "topology_mode must be either 'mesh' or 'hub_and_spoke'."
  }
}

variable "enable_direct_connectivity" {
  type        = bool
  default     = true
  description = "When topology_mode is 'hub_and_spoke', enables direct spoke-to-spoke ConnectedGroup connectivity inside the spoke network group."
}

variable "deploy_connectivity" {
  type        = bool
  default     = false
  description = "Set false for the BEFORE test (spokes isolated), then true to commit the connectivity configuration deployment."
}

variable "deploy_test_vms" {
  type        = bool
  default     = true
  description = "Deploy lightweight Ubuntu VMs (no public IPs; use Azure Bastion or Serial Console/Run Command) to test reachability."
}

variable "vm_size" {
  type        = string
  default     = "Standard_B1s"
  description = "Lightweight VM size for ICMP ping reachability tests."
}

variable "admin_username" {
  type        = string
  default     = "azureuser"
  description = "Linux admin username for the test VMs."
}

variable "ssh_public_key" {
  type        = string
  default     = ""
  description = "SSH public key for the test VMs (required when deploy_test_vms = true). Do not commit private keys."
}
