variable "subscription_id" {
  description = "Azure subscription ID where the lab resources will be deployed."
  type        = string
}

variable "location" {
  description = "Azure region with Network Watcher, VNet flow logs, and Traffic Analytics support (e.g., eastus2, westeurope)."
  type        = string
  default     = "eastus2"
}

variable "prefix" {
  description = "Short lowercase alphanumeric prefix for globally unique resource names (3-10 chars)."
  type        = string
  default     = "flwlab01"
}

variable "network_watcher_resource_group" {
  description = "Resource group containing your regional Network Watcher (default: NetworkWatcherRG)."
  type        = string
  default     = "NetworkWatcherRG"
}

variable "retention_days" {
  description = "Number of days to retain raw VNet flow log JSON blobs in Azure Storage."
  type        = number
  default     = 7
}

variable "traffic_analytics_interval_minutes" {
  description = "Traffic Analytics processing interval in minutes: 60 (default, every 1 hour) or 10 (every 10 minutes)."
  type        = number
  default     = 10

  validation {
    condition     = contains([10, 60], var.traffic_analytics_interval_minutes)
    error_message = "traffic_analytics_interval_minutes must be 10 or 60."
  }
}
