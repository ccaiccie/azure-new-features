# Azure DNS security policy: filter and log DNS at the VNet

Terraform practice lab for the Azure New Features video "Azure DNS Security Policy: Block, Allow and Alert on DNS at the VNet" (YouTube playlist **azure new features**, Network Technician channel).

Azure DNS security policy (Microsoft Learn now also calls it **DNS resolver policy**) filters and logs the DNS queries that resources in a virtual network send to Azure-provided DNS (168.63.129.16). Rules match domain lists, run in priority order (100–65000, lower number wins) and take one of three actions: **Allow**, **Block** or **Alert**. A Microsoft-managed list, `AzureDnsThreatIntel`, can be used like any other domain list.

## What it builds

| Piece | Why it matters |
| --- | --- |
| Resource group, VNet `10.40.0.0/16`, subnet, small Ubuntu VM (no public IP) | The VNet uses Azure-provided DNS, which is where the policy is enforced; tests run through `az vm run-command` |
| Three DNS domain lists: `blocklist`, `allowlist`, `watchlist` | Regional lists of domains (trailing dot; a domain also covers its subdomains) |
| `Microsoft.Network/dnsResolverPolicies` | The policy itself, in the same region as the VNet |
| Rule 100 Allow `allowlist` | A higher-priority exception carved out of the block list |
| Rule 200 Block `blocklist` | Blocked names are answered with a CNAME to `blockpolicy.azuredns.invalid`, so they never resolve |
| Rule 300 Alert `watchlist` | Resolved normally, but each query is logged with the Alert action |
| Rule 400 `AzureDnsThreatIntel` (Alert by default) | Microsoft's managed threat intelligence list; switch to Block after reviewing logs |
| Virtual network link | Applies the policy to every resource in the VNet (one policy per VNet) |
| Log Analytics workspace + diagnostic setting `DnsResponse` | Every query lands in the `DNSQueryLogs` table |

The azurerm provider has no native resolver policy resources yet, so the policy, rules, lists and link use the **AzAPI** provider (`azapi_resource`). The GA API version `2025-05-01` is used everywhere except the threat intelligence rule, which needs `2025-10-01-preview` for `managedDomainLists`.

## Prerequisites

- An Azure subscription where you can create a VM, and `az login` in a terminal on your computer.
- Terraform 1.6 or newer. Providers: `hashicorp/azurerm` (>= 4.20), `Azure/azapi` (>= 2.2), `hashicorp/random`.
- Azure CLI 2.60 or newer (for `az vm run-command` and `az monitor log-analytics query`).
- Pick a region where Azure DNS security policy is available (the default is `eastus2`).

## Cost warning

A B1s VM, its disk and a little Log Analytics ingestion are billed while the lab exists. **Run `terraform destroy` when you finish.**

## Steps

```bash
cp terraform.tfvars.example terraform.tfvars   # set subscription_id
terraform init
terraform validate
terraform plan
terraform apply
terraform output rules
```

## Test from inside the VNet

Run the printed test command (it runs `dig` on the VM through Azure-provided DNS):

```bash
eval "$(terraform output -raw test_command)"
```

Expected results with the default lists:

| Query | Rule that wins | Expected answer |
| --- | --- | --- |
| `www.example.org` | 100 Allow (allowlist) | normal A record |
| `example.org`, `mail.example.org` | 200 Block (blocklist covers subdomains) | `CNAME blockpolicy.azuredns.invalid.` |
| `badsite.example.net` | 200 Block | `CNAME blockpolicy.azuredns.invalid.` |
| `example.com` | 300 Alert | normal A record, logged as Alert |
| `microsoft.com` | no rule matches | normal A record, logged |

Note that `www.example.org` resolves even though `example.org` is blocked: the Allow rule has the lower priority number, so it is evaluated first and wins.

## Verify in the logs

Allow 5–15 minutes for the first records, then:

```bash
LAW=$(terraform output -raw log_analytics_workspace_id)
az monitor log-analytics query -w "$LAW" --analytics-query \
  "DNSQueryLogs | project TimeGenerated, SourceIpAddress, QueryName, QueryType, ResolverPolicyRuleAction, OperationName | order by TimeGenerated desc | take 30" -o table
```

You should see `ResolverPolicyRuleAction` values of `Allow`, `Block` and `Alert`, and the VM's private address (`terraform output vm_private_ip`) as `SourceIpAddress`.

## Experiments

1. Swap the priorities of the Allow and Block rules (set Allow to 250) and apply: `www.example.org` is now blocked, because the Block rule is evaluated first.
2. Set `threat_intel_action = "Block"` and apply. Review the logs for Alert hits first in a real environment.
3. Point the VNet at an outside resolver (`dns_servers = ["1.1.1.1"]` on the VNet, then restart the VM): queries no longer go to Azure-provided DNS, so the policy cannot see or block them. This is why you also block outbound port 53 to the internet with an NSG or Azure Firewall.
4. Create a second VNet in the same region and add a second `virtualNetworkLinks` child: one policy, many VNets. Try linking the same VNet to a second policy and note the error.

## Cleanup

```bash
terraform destroy
```

Confirm the resource group `rg-dnspolicy-lab` is gone: `az group exists -n rg-dnspolicy-lab` should print `false`.

## References

- Overview of DNS resolver policy (DNS security policy) — https://learn.microsoft.com/azure/dns/dns-security-policy
- Secure and view DNS traffic — https://learn.microsoft.com/azure/dns/dns-traffic-log-how-to
- ARM/AzAPI reference: Microsoft.Network/dnsResolverPolicies — https://learn.microsoft.com/azure/templates/microsoft.network/dnsresolverpolicies
- az dns-resolver policy — https://learn.microsoft.com/cli/azure/dns-resolver/policy
