# Azure Logic Apps Standard MSMQ Private Network Lab (Nov 20, 2026 Announcements)

This Terraform practice lab builds the Azure private-network foundation for the **MSMQ built-in connector for Azure Logic Apps Standard** (public preview, announced November 20, 2026) and documents how it differs from **SQL as a storage provider for Hybrid Logic Apps** (generally available, announced November 20, 2026).

## Scope Note: Two Distinct Deployment Models

The two November 20, 2026 announcements are complementary modernization paths, **not** the same hosting model:

1. **MSMQ built-in connector (Public Preview):** Runs inside **Azure Logic Apps Standard** and communicates over a private network (VNet integration, and optionally VPN or ExpressRoute) to a lightweight **MSMQ Broker** Windows service running alongside MSMQ on Windows Server 2019 or later (default TCP port `5050`).
2. **SQL as a storage provider (GA):** Supported **only for Hybrid Logic Apps** running on customer-managed infrastructure (Azure Arc-enabled Kubernetes in datacenters, edge locations, or regulated environments). It is **not** supported for regular Azure-hosted Logic Apps Standard.

Accordingly, the Azure-hosted Logic App Standard in this lab uses an Azure Storage account as required by the platform, while this README documents the separate Hybrid Logic Apps SQL storage requirements honestly.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) `>= 1.6.0`
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) signed in (`az login`) with permissions to create resource groups, VNets, NSGs, VMs, Private DNS zones, and Logic Apps Standard
- A strong password for the Windows Server VM passed via `TF_VAR_broker_admin_password` (never commit secrets)

## What This Lab Builds

- **Resource Group:** `rg-la-msmq-lab-<suffix>`
- **Virtual Network (`10.42.0.0/16`):**
  - `snet-logicapp-integration` (`10.42.1.0/24`): dedicated subnet delegated to `Microsoft.Web/serverFarms` for Logic Apps Standard VNet integration. Do **not** place the MSMQ Broker VM in this subnet.
  - `snet-msmq-broker` (`10.42.2.0/24`): separate private subnet hosting the Windows Server 2022 MSMQ Broker VM.
  - `AzureBastionSubnet` (`10.42.3.0/26`, optional when `enable_bastion = true`): private browser-based RDP access without giving the broker VM a public IP.
- **Network Security Groups (NSGs):**
  - Integration subnet NSG allows outbound TCP `5050` from `10.42.1.0/24` to `10.42.2.0/24`.
  - Broker subnet NSG allows inbound TCP `5050` **only** from `10.42.1.0/24`, and explicitly denies inbound TCP `5050`, RDP (`3389`), and WinRM (`5985-5986`) from `Internet`.
- **Private Windows Server 2022 VM (`vm-msmq-broker`):** Deployed in `snet-msmq-broker` with **no public IP address**.
- **Private DNS Zone (`msmq.internal.lab`):** Linked to the VNet with an `A` record (`broker.msmq.internal.lab`) pointing to the VM's private IP.
- **Azure Logic Apps Standard (`WS1` plan):** Integrated into `snet-logicapp-integration` with `vnet_route_all_enabled = true`.

## Apply Steps

```powershell
# Authenticate to Azure
az login

# Supply the VM administrator password without storing it in git
$env:TF_VAR_broker_admin_password = "ReplaceWithStrongPassword!"

terraform init
terraform plan -out tfplan
terraform apply tfplan
```

To include Azure Bastion for private management access to `vm-msmq-broker`:

```powershell
terraform apply -var="enable_bastion=true"
```

## Post-Apply Verification Steps

1. **Confirm VNet Integration on the Logic App Standard:**
   ```powershell
   $rg = terraform output -raw resource_group_name
   $la = terraform output -raw logic_app_name
   az logicapp show --resource-group $rg --name $la --query "{vnetSubnet:virtualNetworkSubnetId,routeAll:siteConfig.vnetRouteAllEnabled}"
   ```
   Confirm `virtualNetworkSubnetId` points to `snet-logicapp-integration` and `vnetRouteAllEnabled` is `true`.

2. **Confirm NSG Intent on the Broker Subnet:**
   ```powershell
   az network nsg rule list --resource-group $rg --nsg-name nsg-la-msmq-lab-broker --output table
   ```
   Confirm `Allow-Inbound-MsmqBroker-From-LogicApps` permits TCP `5050` only from `10.42.1.0/24`, and that `Deny-Inbound-MsmqBroker-From-Internet` and `Deny-Inbound-Public-Management` are present.

3. **Confirm No Public IP on the Broker VM:**
   ```powershell
   az vm list-ip-addresses --resource-group $rg --name vm-msmq-broker --output table
   ```
   Confirm only a private IP in `10.42.2.0/24` is listed.

4. **Install the MSMQ Broker Service on the Windows VM (Manual / Script Step):**
   Connect privately to `vm-msmq-broker` (via Azure Bastion, VPN, or ExpressRoute — never public RDP) and run Microsoft's official `Install-MsmqEnvironmentService.ps1` script from an elevated PowerShell session. The script installs Windows MSMQ features if needed, registers and starts the MSMQ Broker Windows service on TCP port `5050`, opens the Windows Firewall rule, and runs a health check. Create a local private MSMQ queue (for example, `.\private$\orders`) on the broker host.

5. **Validate the Private TCP 5050 Path from Logic Apps Kudu Console:**
   Open the Kudu URL from `terraform output logic_app_kudu_url`, open the Debug Console (CMD or PowerShell), and run the exact command from `terraform output kudu_tcpping_command`:
   ```cmd
   tcpping <BROKER-PRIVATE-IP> 5050
   ```
   A successful connection confirms VNet integration, routing, NSGs, Windows Firewall, and the MSMQ Broker listener are all aligned before you create the MSMQ connector connection in the Logic App designer.

## Honest `azurerm` Provider Gaps

Terraform's `azurerm` provider cleanly provisions the Azure networking, NSGs, Private DNS, Windows VM, and VNet-integrated Logic Apps Standard host, but several pieces of the November 20, 2026 announcements are **not** natively managed as `azurerm` resources:

- **MSMQ Windows features and MSMQ Broker service:** Installed inside the Windows Server guest OS using `Install-MsmqEnvironmentService.ps1` (or your VM configuration management tooling).
- **MSMQ built-in connector connection and Standard workflows:** Configured inside the Logic Apps Standard designer, `connections.json`, and workflow `workflow.json` definitions (deployable via Visual Studio Code, CI/CD, or ZipDeploy). Remember to match `Is Transactional` to the queue setting, use a local private queue on the broker host for triggers, assign one workflow per receive queue, and make receive workflows idempotent for at-least-once delivery.
- **Hybrid Logic Apps on Azure Arc-enabled Kubernetes (including RKE2 and OpenShift):** Requires an existing customer-managed Kubernetes cluster onboarded to Azure Arc, the Logic Apps Hybrid extension, an SMB file share for static app artifacts, and deployment via Azure Portal / CLI / DevOps workflows rather than a single `azurerm_logic_app_standard` resource.
- **SQL as a storage provider for Hybrid Logic Apps (GA):** Configured as the connection string on the Hybrid Logic Apps deployment targeting your customer-managed SQL Server database. The Hybrid runtime initializes and owns its own schema on first connect — do not manually alter, rename, drop, or delete rows from runtime tables.

## Cost Notes

Running this lab incurs hourly Azure charges for:
- **App Service Plan (`WS1`):** Workflow Standard compute tier
- **Windows Server VM (`Standard_D2s_v3`):** Compute plus `StandardSSD_LRS` OS disk
- **Storage Account & Private DNS Zone:** Minimal usage charges
- **Azure Bastion (`Basic`, optional):** Only incurred if `enable_bastion = true`

Destroy the lab promptly when finished testing.

## Cleanup

```powershell
terraform destroy
```

## Official References

- [Announcing the MSMQ built-in connector for Azure Logic Apps Standard (Public Preview)](https://techcommunity.microsoft.com/blog/integrationsonazureblog/announcing-the-msmq-built-in-connector-for-azure-logic-apps-standard/4574215)
- [Announcing General Availability of SQL as a storage provider for Hybrid Logic Apps](https://techcommunity.microsoft.com/blog/integrationsonazureblog/announcing-general-availability-of-sql-as-a-storage-provider-for-hybrid-logic-ap/4574517)
- [What's new in Azure Logic Apps at Microsoft Ignite 2026](https://techcommunity.microsoft.com/blog/integrationsonazureblog/whats-new-in-azure-logic-apps-at-microsoft-ignite-2026/4574191)
- [Set up SQL database storage for Standard / Hybrid workflows](https://learn.microsoft.com/en-us/azure/logic-apps/set-up-sql-database-storage-standard)
