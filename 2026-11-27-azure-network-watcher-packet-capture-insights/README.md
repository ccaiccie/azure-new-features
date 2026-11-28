# Azure Network Watcher Packet Capture Insights (Preview) — Practice Lab

Build a self-contained Azure lab in a documented Packet Capture Insights preview region (`westus2` by default) with Terraform, generate DNS, HTTP, and TLS test traffic between two Ubuntu VMs, stop the capture with Azure CLI, trigger **Packet capture insights (preview)** via the official ARM REST API (`startInsight`), and run KQL hunts across the four `NWPacketCapture*` Log Analytics tables.

> **Cost Warning:** The two Ubuntu VMs (`client-vm` and `web-vm`), the Standard public IP address, the Standard storage account, Log Analytics ingestion, and Network Watcher packet captures bill until they are deleted. Run `terraform destroy` as soon as you finish the lab.

> **Preview Notice:** Azure Network Watcher packet capture insights is in **public preview** (announced November 17, 2026) in 13 supported regions: East US, UK South, North Europe, South Central US, Japan East, East US 2, West Europe, Australia East, Central India, Canada Central, West US 2, Southeast Asia, and South Africa North. AI-generated findings are supporting guidance only and should be validated against the underlying `.cap` capture data.

> **Known Terraform Provider Gap:** As of November 2026, the `azurerm` Terraform provider has no resource for Packet Capture Insights. This lab creates the VNet, VMs, extensions, storage account, Log Analytics workspace, and `azurerm_virtual_machine_packet_capture` with Terraform, then calls the official ARM REST API (`startInsight?api-version=2025-05-01`) via `az rest` (or you can trigger it in the Azure portal).

---

## Official Sources

- [Packet capture insights overview (preview) — Microsoft Learn](https://learn.microsoft.com/en-us/azure/network-watcher/packet-capture-insights-overview)
- [Packet capture insights how-to — Microsoft Learn](https://learn.microsoft.com/en-us/azure/network-watcher/packet-capture-insights-how-to)
- [Start, stop, download, and delete packet captures — Microsoft Learn](https://learn.microsoft.com/en-us/azure/network-watcher/packet-capture-manage)
- [Azure Updates: Public Preview — Azure Network Watcher Packet capture insights (Nov 17, 2026)](https://mc.merill.net/message/AZ578172)

---

## Prerequisites

- Azure subscription with RBAC permissions to deploy resources and generate insights:
  - `Microsoft.Network/networkWatchers/packetCaptures/read`
  - `Microsoft.Network/networkWatchers/packetCaptures/startInsight/action`
  - `Microsoft.Network/networkWatchers/packetCaptures/queryInsight/action`
  - `Microsoft.Storage/storageAccounts/listAccountSas/action`
  - `Microsoft.Operationalinsights/workspaces/write`
- Terraform `>= 1.6.0` and Azure CLI (`az login`)
- An SSH key pair (`ssh-keygen -t ed25519`)

---

## 1. Deploy the Lab with Terraform

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your SSH public key and your /32 public IP for admin_source_cidr

terraform init
terraform plan
terraform apply
```

> **Note:** If your subscription already has a Network Watcher in `westus2` (commonly in `NetworkWatcherRG`), Azure allows only one Network Watcher per subscription per region. In that case, replace the `azurerm_network_watcher.lab` resource in `main.tf` with a `data "azurerm_network_watcher"` block referencing your existing Network Watcher.

---

## 2. Generate DNS, HTTP, and TLS Test Traffic

SSH to `client-vm` using the `client_vm_public_ip` output:

```bash
CLIENT_IP=$(terraform output -raw client_vm_public_ip)
ssh azureuser@"$CLIENT_IP"
```

Run DNS (valid + NXDOMAIN), HTTP (200 + 404), and TLS (SNI) test traffic from `client-vm`:

```bash
# DNS lookups (valid and failing NXDOMAIN)
dig learn.microsoft.com +short
dig nonexistent-test-host.invalid +short

# HTTP requests to web-vm (10.42.1.20)
curl -i http://10.42.1.20/
curl -i http://10.42.1.20/missing

# HTTPS/TLS request with explicit SNI (self-signed cert on web-vm)
curl -vk --resolve web.lab.internal:443:10.42.1.20 https://web.lab.internal/
exit
```

---

## 3. Stop the Packet Capture and Confirm Stopped State

Insights can only be generated when the packet capture is in the **Stopped** state.

```bash
LOCATION=$(terraform output -raw location)
PCAP_NAME=$(terraform output -raw packet_capture_name)

az network watcher packet-capture stop \
  --location "$LOCATION" \
  --name "$PCAP_NAME"

az network watcher packet-capture show-status \
  --location "$LOCATION" \
  --name "$PCAP_NAME"
```

Wait until `"packetCaptureStatus": "Stopped"` appears before calling `startInsight`.

---

## 4. Generate Packet Capture Insights via REST API

Call the documented ARM REST endpoint `startInsight?api-version=2025-05-01` using `az rest` so Azure generates the AI-assisted summary and ingests protocol logs into your Log Analytics workspace (same subscription and region):

```bash
PCAP_ID=$(terraform output -raw packet_capture_id)
LAW_ID=$(terraform output -raw log_analytics_workspace_id)

az rest \
  --method post \
  --url "https://management.azure.com${PCAP_ID}/startInsight?api-version=2025-05-01" \
  --body "{
    \"properties\": {
      \"outputs\": [
        {
          \"type\": \"Workspace\",
          \"ResourceId\": \"${LAW_ID}\",
          \"setting\": \"\"
        }
      ]
    }
  }"
```

Alternatively, open **Network Watcher -> Packet capture** in the Azure portal, select `pcap-client-insights-lab`, set **Store detailed network logs for querying** to **Yes**, pick your Log Analytics workspace, and click **Generate insights**.

---

## 5. Run KQL Hunts and Validate

Open your Log Analytics workspace in the Azure portal (`Logs`) and run the queries in [queries.kql](./queries.kql) across:

- `NWPacketCaptureNetworkSession`
- `NWPacketCaptureDnsQuery`
- `NWPacketCaptureHttpTransaction`
- `NWPacketCaptureTlsSession`

Filter by `PacketCaptureResourceId` to isolate this capture, use `EventTs` for observed traffic timestamps (`TimeGenerated` is ingestion time), and correlate records across tables with `FlowId`. Remember to validate AI-generated findings against the raw `.cap` file in the storage account.

---

## 6. Teardown and Cleanup

Destroy all lab resources when finished so billing stops immediately:

```bash
terraform destroy
```

If you created any extra packet captures manually outside Terraform, delete them with `az network watcher packet-capture delete --location "$LOCATION" --name <name>` and remove any leftover `.cap` blobs from your storage account.
