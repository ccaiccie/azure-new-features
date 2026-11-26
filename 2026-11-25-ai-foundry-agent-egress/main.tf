# Foundry Agent Service Managed Virtual Network & Approved Outbound Egress Lab
# Based on Microsoft Learn:
#   https://learn.microsoft.com/en-us/azure/foundry/how-to/managed-virtual-network

locals {
  rg_name      = "rg-${var.prefix}-foundry-egress"
  foundry_name = "${var.prefix}foundry01"
  storage_name = lower("${var.prefix}st01")
  # Built-in role: Azure AI Enterprise Network Connection Approver
  network_approver_role_id = "b556d68e-0be0-4f35-a333-ad7ee1ce17ea"
}

resource "azurerm_resource_group" "lab" {
  name     = local.rg_name
  location = var.location
}

resource "azurerm_storage_account" "agent_data" {
  name                          = local.storage_name
  resource_group_name           = azurerm_resource_group.lab.name
  location                      = azurerm_resource_group.lab.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  public_network_access_enabled = false
}

# Create Foundry (AIServices) account with Microsoft-managed network injection
# at creation time (cannot be added after creation).
resource "azapi_resource" "foundry_account" {
  type      = "Microsoft.CognitiveServices/accounts@2026-05-01"
  name      = local.foundry_name
  parent_id = azurerm_resource_group.lab.id
  location  = azurerm_resource_group.lab.location

  identity {
    type = "SystemAssigned"
  }

  body = {
    kind = "AIServices"
    sku = {
      name = "S0"
    }
    properties = {
      allowProjectManagement = true
      customSubDomainName    = local.foundry_name
      publicNetworkAccess    = "Disabled"
      disableLocalAuth       = false
      networkInjections = [
        {
          scenario                   = "agent"
          subnetArmId                = ""
          useMicrosoftManagedNetwork = true
        }
      ]
    }
  }

  response_export_values = ["identity.principalId", "properties.endpoint"]
}

# Assign Azure AI Enterprise Network Connection Approver so Foundry can
# create and auto-approve managed private endpoints to customer resources.
resource "azurerm_role_assignment" "foundry_network_approver" {
  scope                = azurerm_resource_group.lab.id
  role_definition_id   = "/subscriptions/${var.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/${local.network_approver_role_id}"
  principal_id         = azapi_resource.foundry_account.output.identity.principalId
  principal_type       = "ServicePrincipal"
}

# Provision the Microsoft-managed virtual network child resource
resource "azapi_resource" "managed_network" {
  type      = "Microsoft.CognitiveServices/accounts/managedNetworks@2026-05-01"
  name      = "default"
  parent_id = azapi_resource.foundry_account.id

  body = {
    properties = {
      managedNetwork = {
        isolationMode = var.isolation_mode
        firewallSku   = var.firewall_sku
      }
    }
  }

  depends_on = [azurerm_role_assignment.foundry_network_approver]
}

# Managed Private Endpoint outbound rule to Azure Storage (blob)
resource "azapi_resource" "rule_storage_pe" {
  type      = "Microsoft.CognitiveServices/accounts/managedNetworks/outboundRules@2026-05-01"
  name      = "pe-storage-blob"
  parent_id = azapi_resource.managed_network.id

  body = {
    properties = {
      type = "PrivateEndpoint"
      destination = {
        serviceResourceId = azurerm_storage_account.agent_data.id
        subresourceTarget = "blob"
        sparkEnabled      = false
      }
    }
  }
}

# Optional FQDN outbound rule (ports 80/443 only; triggers managed Azure Firewall billing)
resource "azapi_resource" "rule_example_fqdn" {
  count     = var.enable_example_fqdn_rule && var.isolation_mode == "AllowOnlyApprovedOutbound" ? 1 : 0
  type      = "Microsoft.CognitiveServices/accounts/managedNetworks/outboundRules@2026-05-01"
  name      = "fqdn-openai-example"
  parent_id = azapi_resource.managed_network.id

  body = {
    properties = {
      type        = "FQDN"
      destination = "*.openai.azure.com"
    }
  }
}
