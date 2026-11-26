# Azure Firewall Wildcard FQDN Support in Network Rules — Practice Lab

This Terraform and Azure CLI practice lab deploys a hub-and-spoke network in Azure to test **wildcard FQDN filtering in Azure Firewall network rules** (generally available November 23, 2026).

## What This Lab Builds

- **Hub VNet (`10.0.0.0/16`)** with `AzureFirewallSubnet` (`10.0.1.0/26`).
- **Azure Firewall Standard** (`afw-hub-wildcard`) and **Azure Firewall Policy** (`afwp-hub-wildcard`) with **DNS Proxy enabled** (`proxy_enabled = true`).
- **Spoke VNet (`10.1.0.0/16`)** with `snet-workload` (`10.1.1.0/24`), peered bidirectionally with the hub.
- **Spoke VNet DNS server** pointed at the Azure Firewall private IP (`azurerm_virtual_network_dns_servers`).
- **User-Defined Route (`0.0.0.0/0`)** sending spoke outbound traffic through the Azure Firewall private IP.
- **Network Rule Collection** (`allow-wildcard-non-http`) containing wildcard FQDN rules:
  - `allow-ntp-wildcard`: UDP port `123` to `*.pool.ntp.org`
  - `allow-contoso-ssh-tcp`: TCP ports `22` and `443` to `*.contoso.com`
- **Log Analytics Workspace** + **Diagnostic Setting** (`Dedicated` / resource-specific tables) collecting `AZFWNetworkRule` and `AZFWDnsQuery`.
- **Spoke Linux VM (`vm-spoke-01`, `10.1.1.4`)** with no public IP (tested via `az vm run-command invoke`).

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) `>= 1.6.0`
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) logged in with `az login` and the target subscription selected (`az account set --subscription "<id>"`)
- An SSH public key (`~/.ssh/id_ed25519.pub` or `~/.ssh/id_rsa.pub`)
- Azure CLI `azure-firewall` extension if using the CLI commands below:
  ```bash
  az extension add --name azure-firewall
  ```

## Regional, SKU, and Provider Notes

- **Regional availability**: Current Microsoft documentation lists **West Central US (`westcentralus`)**, **East Asia (`eastasia`)**, and **UK South (`uksouth`)** as supported regions for wildcard domains in network rules. `variables.tf` validates against those three regions; update the validation block if Microsoft expands regional support later.
- **SKU requirement**: DNS proxy is required for wildcard FQDN network rules and is available on **Azure Firewall Standard** and **Azure Firewall Premium** only. **Azure Firewall Basic** does not support DNS proxy or network-level FQDN filtering.
- **Provider support**: `azurerm_firewall_policy_rule_collection_group` accepts wildcard strings directly in `destination_fqdns` (for example `"*.pool.ntp.org"` and `"*.contoso.com"`), and `azurerm_firewall_policy` exposes `dns { proxy_enabled = true }`. If your Azure subscription or region rejects a wildcard pattern during `apply`, verify the region is one of the supported regions above, or configure the rule via the Azure CLI / Azure portal steps below.
- **VM DNS refresh**: If you update VNet DNS settings on an existing VM, restart the VM so it picks up the Azure Firewall private IP as its DNS server. In this lab, `depends_on = [azurerm_virtual_network_dns_servers.spoke]` ensures the DNS server setting is applied before the spoke NIC is created.

## Cost Notes

Azure Firewall Standard incurs an hourly deployment charge plus a per-GB data processing charge, along with small charges for the Standard Public IP, `Standard_B1s` VM, and Log Analytics ingestion. **Run `terraform destroy` as soon as you finish testing** so the firewall does not accrue ongoing hourly charges.

## 1. Deploy the Lab

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with a unique Log Analytics workspace name and your SSH public key

terraform init
terraform plan
terraform apply
```

Note the `firewall_private_ip` and `log_analytics_workspace_id` outputs.

### Equivalent Azure CLI / Portal Steps (Reference)

If you prefer to enable DNS proxy and point a VNet at the firewall using Azure CLI:

```bash
# Enable DNS proxy on a standalone firewall
az network firewall update \
  --name afw-hub-wildcard \
  --resource-group rg-azfw-wildcard-lab \
  --enable-dns-proxy true

# Point the spoke VNet DNS server at the firewall private IP
az network vnet update \
  --name vnet-spoke-app \
  --resource-group rg-azfw-wildcard-lab \
  --dns-servers <firewall-private-ip>
```

In the Azure portal, open your **Firewall Policy** -> **DNS** -> enable **DNS Settings** and **DNS Proxy**, then add a **Network Rule** whose **Destination type** is **FQDN** and **Destination** is `*.pool.ntp.org` (or `*.contoso.com`).

## 2. Verify DNS Proxy, Wildcard Allow, and Out-of-Domain Deny

Run commands on `vm-spoke-01` without needing a public IP:

```bash
# 1. Confirm the VM is using the Azure Firewall private IP for DNS
az vm run-command invoke \
  --resource-group rg-azfw-wildcard-lab \
  --name vm-spoke-01 \
  --command-id RunShellScript \
  --scripts "resolvectl status || cat /etc/resolv.conf"

# 2. Resolve multiple subdomains under the allowed wildcard (*.pool.ntp.org)
#    and send UDP/123 probes (the first packet to a newly resolved subdomain
#    may be briefly delayed while the firewall programs the learned IP;
#    rules refresh every 15 seconds).
az vm run-command invoke \
  --resource-group rg-azfw-wildcard-lab \
  --name vm-spoke-01 \
  --command-id RunShellScript \
  --scripts "dig +short 0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org; sleep 2; python3 -c \"
import socket
for host in ['0.pool.ntp.org', '1.pool.ntp.org', '2.pool.ntp.org']:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(3)
    s.sendto(b'\\x1b' + 47*b'\\0', (host, 123))
    try:
        data, addr = s.recvfrom(1024)
        print(host, 'ALLOWED ->', addr, len(data), 'bytes')
    except Exception as e:
        print(host, 'ERROR ->', e)
\""

# 3. Test a host outside the wildcard domain (should be denied by default)
az vm run-command invoke \
  --resource-group rg-azfw-wildcard-lab \
  --name vm-spoke-01 \
  --command-id RunShellScript \
  --scripts "dig +short example.net; nc -zv -w 3 example.net 22 || echo 'DENIED as expected'"
```

## 3. Inspect Logs in Log Analytics

Wait 2–5 minutes for logs to land in Log Analytics, then open **Logs** on the workspace and run:

### Check DNS Proxy Queries (`AZFWDnsQuery`)

```kql
AZFWDnsQuery
| where TimeGenerated > ago(30m)
| project TimeGenerated, SourceIp, Protocol, QueryName, QueryType, ResponseCode, RequestDurationSecs
| order by TimeGenerated desc
```

### Check Matched Network Rules — Allow & Deny (`AZFWNetworkRule`)

```kql
AZFWNetworkRule
| where TimeGenerated > ago(30m)
| project TimeGenerated, Protocol, SourceIp, SourcePort, DestinationIp, DestinationPort, Action, Policy, RuleCollectionGroup, RuleCollection, Rule, ActionReason
| order by TimeGenerated desc
```

You should see:
- `Action == "Allow"` rows for the resolved IPs of `0.pool.ntp.org`, `1.pool.ntp.org`, and `2.pool.ntp.org` matching `Rule == "allow-ntp-wildcard"` in `RuleCollection == "allow-wildcard-non-http"`.
- `Action == "Deny"` rows for `example.net` with `ActionReason == "Default Action"` when no rule matched.

## 4. Cleanup

```bash
terraform destroy
```

Verify the resource group `rg-azfw-wildcard-lab` is deleted so no Azure Firewall charges remain.

## Official References

- [Azure Updates — Wildcard FQDN Support in Azure Firewall Network Rules](https://azure.microsoft.com/updates?id=582030)
- [Use FQDN filtering in network rules](https://learn.microsoft.com/en-us/azure/firewall/fqdn-filtering-network-rules)
- [Azure Firewall FQDN filtering overview](https://learn.microsoft.com/en-us/azure/firewall/domain-filtering-overview)
- [Azure Firewall DNS settings](https://learn.microsoft.com/en-us/azure/firewall/dns-settings)
- [Azure Firewall DNS proxy details](https://learn.microsoft.com/en-us/azure/firewall/dns-details)
- [Monitoring data reference for Azure Firewall](https://learn.microsoft.com/en-us/azure/firewall/monitor-firewall-reference)
