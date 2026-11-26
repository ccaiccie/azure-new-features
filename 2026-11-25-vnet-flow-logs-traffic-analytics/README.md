# Practice Lab — Azure Virtual Network Flow Logs & Traffic Analytics (Managed Identity)

Intended repository path: `ccaiccie/azure-new-features/2026-11-25-vnet-flow-logs-traffic-analytics`

This Terraform and Azure CLI / PowerShell practice lab deploys:
1. A Virtual Network, subnet, and Network Security Group (NSG).
2. A **User-Assigned Managed Identity** granted **`Storage Blob Data Contributor`** on a dedicated Azure Storage account (credential-free flow log writes).
3. A **Log Analytics workspace** and an **Azure Network Watcher Virtual Network Flow Log** targeting the VNet with **Traffic Analytics** enabled (configurable `60`-minute or `10`-minute processing interval).

## Official Microsoft Learn Sources
- Virtual network flow logs overview: https://learn.microsoft.com/en-us/azure/network-watcher/vnet-flow-logs-overview
- Traffic analytics: https://learn.microsoft.com/en-us/azure/network-watcher/traffic-analytics
- Migrate to virtual network flow logs: https://learn.microsoft.com/en-us/azure/network-watcher/nsg-flow-logs-migrate
- Managed identity for virtual network flow logs: https://learn.microsoft.com/en-us/azure/network-watcher/vnet-flow-logs-managed-identity
- Traffic analytics schema: https://learn.microsoft.com/en-us/azure/network-watcher/traffic-analytics-schema

## Prerequisites
- An Azure subscription with Network Watcher enabled in your target region (the default `NetworkWatcherRG` and `NetworkWatcher_<region>`).
- RBAC permissions to create networking, storage, Log Analytics, managed identity, and role assignments (`Owner` or `Contributor` + `User Access Administrator`).
- **Terraform >= 1.6** and **Azure CLI** (`az login`) or **Azure PowerShell** (`Az` module).

## Cost Notice
- Virtual network flow logs incur Azure Storage and Network Watcher log-collection charges; Traffic Analytics incurs processing and Log Analytics ingestion charges.
- Run `terraform destroy` when finished to stop ongoing charges.

## 1. Configure Variables
```bash
cp terraform.tfvars.example terraform.tfvars
# Set subscription_id, location, prefix, and traffic_analytics_interval_minutes (60 or 10)
```

## 2. Deploy with Terraform
```bash
az login
terraform init
terraform plan -out tfplan
terraform apply tfplan
```

## 3. Verify with Azure CLI & Log Analytics (KQL)
Confirm the VNet flow log is enabled with Traffic Analytics:
```bash
az network watcher flow-log show \
  --location <location> \
  --name <flow_log_name>
```

Check Storage blobs under container `insights-logs-flowlogflowevent` (written in JSON at 1-minute intervals), then query `NTANetAnalytics` in your Log Analytics workspace after the processing interval (10 minutes or 1 hour):
```kusto
NTANetAnalytics
| where SubType == "FlowLog"
| summarize AllowedIn = sum(AllowedInFlows), DeniedIn = sum(DeniedInFlows),
            AllowedOut = sum(AllowedOutFlows), DeniedOut = sum(DeniedOutFlows)
  by DestPort, L4Protocol, NSGRule
| order by DeniedIn desc
```

## 4. Destroy & Clean Up
```bash
terraform destroy
```
Verify the resource group is removed:
```bash
az group exists --name <resource_group_name>
```
