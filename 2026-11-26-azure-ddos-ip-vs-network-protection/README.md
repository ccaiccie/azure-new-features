# Azure DDoS IP Protection vs. DDoS Network Protection — Practice Lab

This lab accompanies the Network Technician class **Azure DDoS IP Protection vs. DDoS Network Protection** (playlist: `azure new features`).

> **COST WARNING**
> - **Azure DDoS IP Protection** bills **per protected public IP** (official Azure pricing page: \$199/month per protected public IP, based on 730 hours/month, prorated for active hours).
> - **Azure DDoS Network Protection** bills a fixed monthly charge for a DDoS Protection plan (official Azure pricing page: \$2,944/month including up to 100 protected public IP resources, plus \$29.50/resource/month overage, prorated for active hours). **Disabling Network Protection on a virtual network does NOT stop billing.** You continue to incur charges until you dissociate all virtual networks and **delete the DDoS protection plan resource**.
> - **Default lab path:** `enable_ip_protection = true` and `enable_network_protection = false`. The Network Protection plan is strictly opt-in behind `enable_network_protection`.
> - **Peacetime only:** Never simulate a DDoS attack or run a traffic generator against Azure. Use this lab strictly to configure protection, validate status, and inspect peacetime metrics, alerts, and diagnostic log settings.

## What This Lab Deploys

By default (`enable_ip_protection = true`, `enable_network_protection = false`):
- A Resource Group (`rg-ddos-sku-lab`)
- A Virtual Network (`vnet-ddos-sku-lab`) and subnet (`snet-app`)
- A **Standard SKU**, Static **Public IP address** (`pip-ddos-ip-lab`) with `ddos_protection_mode = "Enabled"` (Azure DDoS IP Protection)

Optional toggles (both default to `false`):
- `enable_network_protection = true` — creates an `azurerm_network_ddos_protection_plan`, links it to `vnet-ddos-sku-lab`, and switches the public IP to `VirtualNetworkInherited`.
- `enable_diagnostic_logging = true` — creates a Log Analytics workspace and diagnostic setting on the public IP forwarding `DDoSProtectionNotifications`, `DDoSMitigationFlowLogs`, and `AllMetrics`.

## Prerequisites

- An Azure subscription with **Network Contributor** (or equivalent custom RBAC permissions)
- Azure CLI (`az --version` 2.0.56 or later) signed in via `az login`
- Terraform `>= 1.5.0`

## Option A: Run with Terraform (Recommended)

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

### Validate in Peacetime

Run the Azure CLI command printed in Terraform outputs (or directly):

```bash
az network public-ip show \
  --resource-group rg-ddos-sku-lab \
  --name pip-ddos-ip-lab \
  --query "{name:name, sku:sku.name, ipAddress:ipAddress, ddosSettings:ddosSettings}"
```

Confirm `"protectionMode": "Enabled"` under `ddosSettings`.

In the Azure portal:
1. Open **Public IP addresses** -> `pip-ddos-ip-lab`.
2. Under **Overview**, select the **Properties** tab -> **DDoS protection**, and verify the **Protection status** shows protected with Protection type **IP**.
3. Under **Monitoring -> Metrics**, verify scope is the public IP and inspect `Under DDoS attack or not` (Aggregation: `Max`, peacetime value `0`) and trigger threshold metrics (`Inbound SYN/TCP/UDP packets to trigger DDoS mitigation`).

## Option B: Run with Azure CLI

See [ddos-lab.sh](./ddos-lab.sh) for the complete command-by-command walkthrough. The Network Protection plan commands are commented out by default to prevent accidental plan billing.

## Destroy & Cleanup (Required to Stop Billing)

### Terraform

```bash
terraform destroy
```

### Azure CLI

```bash
# If you enabled a Network Protection plan, dissociate all VNets first, then delete the plan:
# az network vnet update --resource-group rg-ddos-sku-lab --name vnet-ddos-sku-lab --ddos-protection false
# az network ddos-protection delete --resource-group rg-ddos-sku-lab --name ddos-plan-sku-lab

# Remove the entire lab resource group and all resources inside it:
az group delete --name rg-ddos-sku-lab --yes --no-wait
```

Verify no DDoS protection plans remain in your subscription:

```bash
az network ddos-protection list --output table
```

## Official Sources

- [About Azure DDoS Protection Tier Comparison](https://learn.microsoft.com/en-us/azure/ddos-protection/ddos-protection-sku-comparison)
- [QuickStart: Create and configure Azure DDoS IP Protection using Azure portal](https://learn.microsoft.com/en-us/azure/ddos-protection/manage-ddos-ip-protection-portal)
- [QuickStart: Create and configure Azure DDoS IP Protection using Azure CLI](https://learn.microsoft.com/en-us/azure/ddos-protection/manage-ddos-ip-protection-cli)
- [Quickstart: Create and configure Azure DDoS Network Protection using the Azure portal](https://learn.microsoft.com/en-us/azure/ddos-protection/manage-ddos-protection)
- [QuickStart: Create and configure Azure DDoS Network Protection using Azure CLI](https://learn.microsoft.com/en-us/azure/ddos-protection/manage-ddos-protection-cli)
- [How to switch Azure DDoS Protection tiers using Azure portal](https://learn.microsoft.com/en-us/azure/ddos-protection/ddos-switch-ddos-protection-tier)
- [Monitor Azure DDoS Protection](https://learn.microsoft.com/en-us/azure/ddos-protection/telemetry)
- [Azure DDoS Protection monitoring data reference](https://learn.microsoft.com/en-us/azure/ddos-protection/monitor-ddos-protection-reference)
- [Tutorial: Configure Azure DDoS Protection metric alerts through portal](https://learn.microsoft.com/en-us/azure/ddos-protection/alerts)
- [Tutorial: View Azure DDoS Protection logs in Log Analytics workspace](https://learn.microsoft.com/en-us/azure/ddos-protection/ddos-view-diagnostic-logs)
- [Azure DDoS Protection Pricing](https://azure.microsoft.com/pricing/details/ddos-protection/)
