# Azure NAT Gateway StandardV2 Practice Lab

> **Cost Warning:** The StandardV2 NAT Gateway, StandardV2 IPv4 and IPv6 public IP addresses, the Linux test VM, Log Analytics data ingestion, and any outbound data processed all incur Azure charges until they are deleted. Run `terraform destroy` as soon as you finish testing.

## What This Lab Builds

This Terraform and Azure CLI lab deploys:

1. A **Resource Group** (`rg-natgw-v2-lab` by default).
2. A **dual-stack Virtual Network** (`10.40.0.0/16` and `fd00:40::/48`) with a **private subnet** (`default_outbound_access_enabled = false`).
3. Two **StandardV2 Public IP addresses** (one IPv4, one IPv6). Standard and Basic public IPs are not supported with StandardV2 NAT Gateways.
4. A **zone-redundant StandardV2 NAT Gateway** (`sku_name = "StandardV2"`, with `zones` omitted) associated with both StandardV2 public IPs and the workload subnet.
5. A **Log Analytics Workspace** and an **Azure Monitor Diagnostic Setting** sending the `NatGatewayFlowlogsV1` category to Log Analytics.
6. A small **dual-stack Ubuntu 24.04 Linux VM** (`Standard_B1s`) with **no instance-level public IP**, so all outbound traffic exits through the StandardV2 NAT Gateway.

## Provider & NAT64 Note

- The Terraform `azurerm` provider (`>= 4.20.0`) supports `sku_name = "StandardV2"` on `azurerm_nat_gateway` (with `zones` omitted) and `sku = "StandardV2"` on `azurerm_public_ip`.
- Enabling **NAT64** is performed via the Azure CLI (`az network nat gateway update --nat64 Enabled`), the Azure portal (**Configuration > NAT64 > Enabled**), or ARM/REST (`nat64 = "Enabled"`).
- **Why this lab does not deploy a DNS64 resolver:** Azure does not provide a managed DNS64 service for NAT64. Per Microsoft documentation, NAT64 requires a third-party DNS64 solution to synthesize `AAAA` records under `64:ff9b::/96` for IPv4-only destinations. Deploying and maintaining a third-party DNS64 server is intentionally omitted from this quick lab to keep costs and complexity low.

## Prerequisites

- An active Azure subscription
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6.0
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) signed in via `az login`
- An SSH public key (for example `~/.ssh/id_rsa.pub`)
- Choose a region that supports StandardV2 NAT Gateway (not Canada East, India South Central, Sweden South, or West India)

## Step 1 — Deploy with Terraform

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars if you want to change location or ssh_public_key_path

terraform init
terraform plan
terraform apply
```

Note the outputs: `nat_gateway_ipv4_address`, `nat_gateway_ipv6_address`, `nat_gateway_name`, and `test_vm_name`.

## Step 2 — (Optional) Enable NAT64 via Azure CLI

```bash
az network nat gateway update \
  --resource-group rg-natgw-v2-lab \
  --name natv2lab-natgw-v2 \
  --nat64 Enabled
```

Verify the setting:

```bash
az network nat gateway show \
  --resource-group rg-natgw-v2-lab \
  --name natv2lab-natgw-v2 \
  --query "{sku:sku.name, nat64:nat64, zones:zones}" \
  --output table
```

## Step 3 — Verify Outbound Connectivity from the Private VM

Because the VM has no public IP, run the check with `az vm run-command invoke` (no Azure Bastion required):

```bash
az vm run-command invoke \
  --resource-group rg-natgw-v2-lab \
  --name natv2lab-vm \
  --command-id RunShellScript \
  --scripts "curl -4 -s https://api.ipify.org; echo; curl -6 -s https://api64.ipify.org; echo; ping -4 -c 3 1.1.1.1"
```

Confirm that:
- The returned IPv4 address matches `terraform output nat_gateway_ipv4_address`.
- The returned IPv6 address matches `terraform output nat_gateway_ipv6_address`.
- `ping` succeeds (StandardV2 supports outbound ICMP Echo Request and Echo Reply by default).

## Step 4 — Query Flow Logs in Log Analytics

> **Note:** After configuring the diagnostic setting, it can take **up to 90 minutes** for `NatGatewayFlowlogsV1` logs to appear in Log Analytics.

Open your Log Analytics workspace (`natv2lab-law`) in the Azure portal, go to **Logs**, and run the official top-talkers KQL query:

```kql
NatGatewayFlowlogsV1
| where TimeGenerated > ago(1d)
| summarize TotalPacketsSent = sum(PacketsSent) by SourceIP
| sort by TotalPacketsSent desc
```

## Step 5 — Destroy Everything (Stop Billing)

```bash
terraform destroy
```

Verify the resource group is gone (or delete it directly if needed):

```bash
az group delete --name rg-natgw-v2-lab --yes --no-wait
```

## Official Documentation References

- What is Azure NAT Gateway: https://learn.microsoft.com/en-us/azure/nat-gateway/nat-overview
- Azure NAT Gateway SKUs: https://learn.microsoft.com/en-us/azure/nat-gateway/nat-sku
- NAT Gateway Resource (NAT64, Availability Zones, Timers): https://learn.microsoft.com/en-us/azure/nat-gateway/nat-gateway-resource
- Monitor with StandardV2 NAT Gateway Flow Logs: https://learn.microsoft.com/en-us/azure/nat-gateway/monitor-nat-gateway-flow-logs
- Quickstart: Create a StandardV2 NAT Gateway: https://learn.microsoft.com/en-us/azure/nat-gateway/quickstart-create-nat-gateway-v2
- Design Virtual Networks with Azure NAT Gateway: https://learn.microsoft.com/en-us/azure/nat-gateway/nat-gateway-design
- Reliability in Azure NAT Gateway: https://learn.microsoft.com/en-us/azure/reliability/reliability-nat-gateway
- Azure CLI `az network nat gateway`: https://learn.microsoft.com/en-us/cli/azure/network/nat/gateway
