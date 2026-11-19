# Azure DNS security policy (DNS resolver policy) lab.
# azurerm has no native resource for resolver policies yet, so the policy pieces use AzAPI
# with the ARM types Microsoft.Network/dnsResolverPolicies, .../dnsSecurityRules,
# .../virtualNetworkLinks and Microsoft.Network/dnsResolverDomainLists.

locals {
  api_ga      = "2025-05-01"         # GA API: policy, domain lists, rules, VNet links
  api_managed = "2025-10-01-preview" # adds managedDomainLists (AzureDnsThreatIntel) on rules
}

resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
}

resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
}

# ---------- network: one spoke VNet that uses Azure-provided DNS (168.63.129.16) ----------
resource "azurerm_virtual_network" "spoke" {
  name                = "${var.name_prefix}-vnet"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.40.0.0/16"]
  # no dns_servers: the VNet uses Azure-provided DNS, which is where the policy is enforced
}

resource "azurerm_subnet" "workload" {
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = ["10.40.1.0/24"]
}

# ---------- test VM, no public IP: tests run through az vm run-command ----------
resource "azurerm_network_interface" "vm" {
  name                = "${var.name_prefix}-vm-nic"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.workload.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "random_password" "vm" {
  length           = 24
  special          = true
  override_special = "!@#%*-_"
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                            = "${var.name_prefix}-vm"
  location                        = azurerm_resource_group.lab.location
  resource_group_name             = azurerm_resource_group.lab.name
  size                            = var.vm_size
  admin_username                  = "labadmin"
  admin_password                  = random_password.vm.result
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.vm.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

# ---------- logging: DnsResponse logs land in the DNSQueryLogs table ----------
resource "azurerm_log_analytics_workspace" "dns" {
  name                = "${var.name_prefix}-law-${random_string.suffix.result}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# ---------- DNS domain lists (regional, siblings of the policy) ----------
resource "azapi_resource" "blocklist" {
  type      = "Microsoft.Network/dnsResolverDomainLists@${local.api_ga}"
  name      = "${var.name_prefix}-blocklist"
  parent_id = azurerm_resource_group.lab.id
  location  = var.location
  body = {
    properties = { domains = var.blocked_domains }
  }
}

resource "azapi_resource" "allowlist" {
  type      = "Microsoft.Network/dnsResolverDomainLists@${local.api_ga}"
  name      = "${var.name_prefix}-allowlist"
  parent_id = azurerm_resource_group.lab.id
  location  = var.location
  body = {
    properties = { domains = var.allowed_domains }
  }
}

resource "azapi_resource" "watchlist" {
  type      = "Microsoft.Network/dnsResolverDomainLists@${local.api_ga}"
  name      = "${var.name_prefix}-watchlist"
  parent_id = azurerm_resource_group.lab.id
  location  = var.location
  body = {
    properties = { domains = var.watched_domains }
  }
}

# ---------- the DNS resolver policy ----------
resource "azapi_resource" "policy" {
  type      = "Microsoft.Network/dnsResolverPolicies@${local.api_ga}"
  name      = "${var.name_prefix}-policy"
  parent_id = azurerm_resource_group.lab.id
  location  = var.location
  body = {
    properties = {}
  }
}

# ---------- DNS traffic rules: lower priority number wins ----------
resource "azapi_resource" "rule_allow" {
  type      = "Microsoft.Network/dnsResolverPolicies/dnsSecurityRules@${local.api_ga}"
  name      = "allow-exceptions"
  parent_id = azapi_resource.policy.id
  location  = var.location
  body = {
    properties = {
      priority               = 100
      action                 = { actionType = "Allow" }
      dnsResolverDomainLists = [{ id = azapi_resource.allowlist.id }]
      dnsSecurityRuleState   = "Enabled"
    }
  }
}

resource "azapi_resource" "rule_block" {
  type      = "Microsoft.Network/dnsResolverPolicies/dnsSecurityRules@${local.api_ga}"
  name      = "block-list"
  parent_id = azapi_resource.policy.id
  location  = var.location
  body = {
    properties = {
      priority               = 200
      action                 = { actionType = "Block" }
      dnsResolverDomainLists = [{ id = azapi_resource.blocklist.id }]
      dnsSecurityRuleState   = "Enabled"
    }
  }
  depends_on = [azapi_resource.rule_allow]
}

resource "azapi_resource" "rule_alert" {
  type      = "Microsoft.Network/dnsResolverPolicies/dnsSecurityRules@${local.api_ga}"
  name      = "alert-watchlist"
  parent_id = azapi_resource.policy.id
  location  = var.location
  body = {
    properties = {
      priority               = 300
      action                 = { actionType = "Alert" }
      dnsResolverDomainLists = [{ id = azapi_resource.watchlist.id }]
      dnsSecurityRuleState   = "Enabled"
    }
  }
  depends_on = [azapi_resource.rule_block]
}

resource "azapi_resource" "rule_threat_intel" {
  type      = "Microsoft.Network/dnsResolverPolicies/dnsSecurityRules@${local.api_managed}"
  name      = "threat-intel"
  parent_id = azapi_resource.policy.id
  location  = var.location
  body = {
    properties = {
      priority             = 400
      action               = { actionType = var.threat_intel_action }
      managedDomainLists   = ["AzureDnsThreatIntel"]
      dnsSecurityRuleState = "Enabled"
    }
  }
  depends_on = [azapi_resource.rule_alert]
}

# ---------- link the VNet: one policy per VNet, same region ----------
resource "azapi_resource" "vnet_link" {
  type      = "Microsoft.Network/dnsResolverPolicies/virtualNetworkLinks@${local.api_ga}"
  name      = "${var.name_prefix}-vnet-link"
  parent_id = azapi_resource.policy.id
  location  = var.location
  body = {
    properties = {
      virtualNetwork = { id = azurerm_virtual_network.spoke.id }
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "dns" {
  name                       = "dns-to-law"
  target_resource_id         = azapi_resource.policy.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.dns.id

  enabled_log {
    category = "DnsResponse"
  }
}
