# Disposable lab: Azure Application Gateway for Containers (Bring-Your-Own deployment strategy)
# Official sources:
# - https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/overview
# - https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/quickstart-create-application-gateway-for-containers-byo-deployment
# - https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/quickstart-deploy-application-gateway-for-containers-alb-controller-helm

resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "lab" {
  name                = "${var.prefix}-vnet"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = [var.vnet_address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "aks" {
  name                 = "subnet-aks"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = [var.aks_subnet_prefix]
}

# Association subnet: minimum /24 (256 addresses), delegated to Microsoft.ServiceNetworking/trafficControllers
resource "azurerm_subnet" "alb" {
  name                 = "subnet-alb"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = [var.alb_subnet_prefix]

  delegation {
    name = "Microsoft.ServiceNetworking/trafficControllers"
    service_delegation {
      name    = "Microsoft.ServiceNetworking/trafficControllers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.prefix}-aks"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  dns_prefix          = "${var.prefix}-aks"

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name           = "system"
    node_count     = var.aks_node_count
    vm_size        = var.aks_node_vm_size
    vnet_subnet_id = azurerm_subnet.aks.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    load_balancer_sku   = "standard"
  }

  tags = var.tags
}

# Look up the AKS-managed node resource group (MC_*) so ALB Controller gets Reader access
data "azurerm_resource_group" "aks_node_rg" {
  name       = azurerm_kubernetes_cluster.aks.node_resource_group
  depends_on = [azurerm_kubernetes_cluster.aks]
}

# User-assigned managed identity for ALB Controller (federated via AKS Workload Identity)
resource "azurerm_user_assigned_identity" "alb" {
  name                = "azure-alb-identity"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "alb" {
  name                = "azure-alb-identity"
  resource_group_name = azurerm_resource_group.lab.name
  parent_id           = azurerm_user_assigned_identity.alb.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.aks.oidc_issuer_url
  subject             = "system:serviceaccount:${var.alb_controller_namespace}:alb-controller-sa"
}

# Role 1: Reader on the AKS node resource group
resource "azurerm_role_assignment" "alb_mc_reader" {
  scope                = data.azurerm_resource_group.aks_node_rg.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.alb.principal_id
}

# Role 2: AppGw for Containers Configuration Manager on the resource group holding the AGC resource
# Note: This built-in role includes data actions that Owner and Contributor do not have.
resource "azurerm_role_assignment" "alb_config_manager" {
  scope                = azurerm_resource_group.lab.id
  role_definition_name = "AppGw for Containers Configuration Manager"
  principal_id         = azurerm_user_assigned_identity.alb.principal_id
}

# Role 3: Network Contributor on the delegated association subnet (grants subnets/join/action)
resource "azurerm_role_assignment" "alb_subnet_join" {
  scope                = azurerm_subnet.alb.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.alb.principal_id
}

# Application Gateway for Containers parent resource (BYO strategy)
resource "azurerm_application_load_balancer" "agfc" {
  name                = "${var.prefix}-alb"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  tags                = var.tags
}

# Child resource 1: Frontend (provides Azure-generated FQDN *.fzXX.alb.azure.com)
resource "azurerm_application_load_balancer_frontend" "frontend" {
  name                         = "test-frontend"
  application_load_balancer_id = azurerm_application_load_balancer.agfc.id
  tags                         = var.tags
}

# Child resource 2: Subnet Association (provisions data plane into delegated /24 subnet; takes ~5-6 minutes)
resource "azurerm_application_load_balancer_subnet_association" "association" {
  name                         = "association-test"
  application_load_balancer_id = azurerm_application_load_balancer.agfc.id
  subnet_id                    = azurerm_subnet.alb.id
  tags                         = var.tags
}
