# Azure Network Security Perimeter: one boundary for PaaS, Transition to Enforced

Terraform practice lab for the Azure New Features video "Azure Network Security Perimeter: One Boundary for PaaS, Transition to Enforced" (YouTube playlist **azure new features**, Network Technician channel).

## What it builds

| Piece | Why it matters |
| --- | --- |
| Storage account (shared keys off), key vault (RBAC), Log Analytics workspace | Three GA perimeter members; SAS is rejected for intra-perimeter and subscription-rule traffic, so the lab uses Entra ID |
| `azurerm_network_security_perimeter` + one profile `data-services` | The boundary and the shared set of rules |
| Inbound rule: your public prefix | Address-prefix rule (inbound only) |
| Inbound rule: your own subscription | Subscription rule (inbound only) |
| Outbound rule: one FQDN | Outbound rules are FQDN only; everything else is denied in Enforced mode |
| Associations: storage in `Learning`, key vault in `Enforced`, workspace in `Learning` | `Learning` is the API/Terraform value for the mode the portal now calls **Transition** |
| Diagnostic setting on the perimeter (`allLogs`) to the workspace | Access logs land in the `NSPAccessLogs` table; the destination sits inside the same perimeter |

## Prerequisites

An Azure subscription, `az login`, Terraform 1.6+, providers `hashicorp/azurerm` 5.14.0 and `hashicorp/random`. Set `allowed_inbound_prefixes` to your own public egress IP (`curl -s https://ifconfig.me` then add `/32`). Give yourself the **Storage Blob Data Contributor** role on the storage account after apply to test data-plane access.

## Cost warning

Storage, key vault operations and Log Analytics ingestion are billed while the lab exists (small amounts). **Run `terraform destroy` when you finish.**

## Steps

```bash
cp terraform.tfvars.example terraform.tfvars   # subscription, your egress prefix
terraform init
terraform validate
terraform plan
terraform apply
terraform output access_modes
```

Test (Entra ID auth, no keys):

```bash
ST=$(terraform output -raw storage_account_name)
az storage container create --account-name "$ST" --name test --auth-mode login     # from your allowed IP
az storage blob list --account-name "$ST" --container-name test --auth-mode login
```

Repeat from a phone hotspot (an address not in any rule). In **Transition** mode it may still work through the storage account's own firewall fallback; set `storage_access_mode = "Enforced"`, apply, and try again: it is denied.

Then query the logs (allow 10–15 minutes):

```kusto
NSPAccessLogs
| order by TimeGenerated desc
| take 50
```

Check the category of each record and the matched rule. Look for `NspPublicInboundPerimeterRulesAllowed`, `NspPublicInboundPerimeterRulesDenied` and, in Transition mode, `NspPublicInboundResourceRulesAllowed` (requests that only passed because of the resource firewall).

## Experiments

1. Remove your prefix from `allowed_inbound_prefixes` while the storage account is Enforced and confirm the denied category.
2. Turn on a trusted-services exception on the key vault: it has no effect in Enforced mode.
3. Add a private endpoint for the storage account: private traffic is allowed without any access rule (`NspPrivateInboundAllowed`).
4. Add a second profile for a different team and move the key vault association to it.

## References

- What is a network security perimeter? — https://learn.microsoft.com/azure/private-link/network-security-perimeter-concepts
- Transition to a network security perimeter — https://learn.microsoft.com/azure/private-link/network-security-perimeter-transition
- Diagnostic logs for network security perimeter — https://learn.microsoft.com/azure/private-link/network-security-perimeter-diagnostic-logs
