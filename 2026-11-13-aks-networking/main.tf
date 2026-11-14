terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "5.14.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "lab" {
  name                = "${var.name_prefix}-vnet"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = [var.vnet_cidr]
}

resource "azurerm_subnet" "aks" {
  name                 = "aks"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = [var.subnet_cidr]
}

resource "azurerm_kubernetes_cluster" "lab" {
  count               = var.create_cluster ? 1 : 0
  name                = "${var.name_prefix}-aks"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  dns_prefix          = var.name_prefix

  sku_tier                  = "Free"
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name           = "system"
    vm_size        = var.vm_size
    node_count     = 1
    vnet_subnet_id = azurerm_subnet.aks.id
  }

  identity {
    type = "SystemAssigned"
  }

  node_provisioning_profile {
    mode = "Manual"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip

    advanced_networking {
      observability_enabled = true
      security_enabled      = true
    }
  }
}

resource "azurerm_kubernetes_fleet_manager" "lab" {
  name                = "${var.name_prefix}-fleet"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
}

resource "azurerm_kubernetes_fleet_member" "lab" {
  count                 = var.create_cluster ? 1 : 0
  name                  = "${var.name_prefix}-member"
  kubernetes_fleet_id   = azurerm_kubernetes_fleet_manager.lab.id
  kubernetes_cluster_id = azurerm_kubernetes_cluster.lab[0].id
}
