# Practice Lab: Azure Firewall Premium IDPS & Threat Intelligence

This compact Terraform and Azure CLI lab deploys an **Azure Firewall Premium** hub with **IDPS** (starting in `Alert` mode and switchable to `Deny`), **Threat Intelligence-based filtering** (with allowlist example), and resource-specific **Log Analytics** diagnostics (`AZFWIdpsSignature` and `AZFWThreatIntel`).

Intended public repository path:
`https://github.com/ccaiccie/azure-new-features/tree/main/2026-11-26-azfw-premium-idps-threat-intel`

## What This Lab Deploys

1. **Hub VNet** (`10.95.0.0/16`) with `AzureFirewallSubnet` (`10.95.1.0/26`) and a Standard Static Public IP.
2. **Log Analytics Workspace** + **Azure Monitor Diagnostic Setting** sending resource-specific tables (`AZFWIdpsSignature`, `AZFWThreatIntel`, `AZFWNetworkRule`, `AZFWApplicationRule`) in `Dedicated` mode.
3. **Azure Firewall Policy (Premium SKU)** configured with:
   - `threat_intelligence_mode = var.threat_intel_mode` (`"Alert"` default, switchable to `"Deny"`)
   - `threat_intelligence_allowlist` (example RFC 5737 CIDR `203.0.113.0/24`)
   - `intrusion_detection`: `mode = var.idps_mode` (`"Alert"` default, switchable to `"Deny"`), RFC 1918 `private_ranges`, optional `signature_overrides` map, and `traffic_bypass` example
   - Sample application rule collection allowing HTTP/HTTPS to Microsoft's official Threat Intelligence test FQDN (`testmaliciousdomain.eastus.cloudapp.azure.com`)
4. **Azure Firewall Premium** (`sku_tier = "Premium"`) attached to the Premium policy.

## Prerequisites & Honest Safety Note

- Terraform `>= 1.6` and Azure CLI (`az login`).
- **Never simulate real attacks, exploits, or DDoS traffic against any public service.**
- To safely test Threat Intelligence outbound logging, Microsoft provides the official test FQDN `testmaliciousdomain.eastus.cloudapp.azure.com` (configure a dummy `hosts` entry such as `1.2.3.4 testmaliciousdomain.eastus.cloudapp.azure.com` on a spoke VM routed through the firewall via UDR, and send an HTTP request).
- **Never commit `terraform.tfvars` or real subscription IDs.**

## Deploy

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars and set your real subscription_id

az login
terraform init
terraform plan -out tfplan
terraform apply tfplan
```

## Inspect Logs (KQL) & Switch IDPS From Alert → Alert and Deny

1. **Query Threat Intelligence events in Log Analytics:**
   ```kql
   AZFWThreatIntel
   | project TimeGenerated, Action, Protocol, SourceIp, DestinationIp, TargetUrl, ThreatDescription
   | order by TimeGenerated desc
   ```
2. **Query IDPS signature events in Log Analytics:**
   ```kql
   AZFWIdpsSignature
   | project TimeGenerated, Action, SignatureId, Category, Severity, SourceIp, DestinationIp, Description
   | order by TimeGenerated desc
   ```
3. **Switch IDPS from `Alert` to `Alert and Deny` (or add a signature override) in `terraform.tfvars`:**
   ```hcl
   idps_mode         = "Deny"
   threat_intel_mode = "Deny"
   ```
   Then re-run `terraform plan -out tfplan && terraform apply tfplan`.

## Destroy & Clean Up (Stop Hourly Premium Charges!)

Azure Firewall Premium bills hourly even when idle. Always destroy the lab immediately after testing:

```bash
terraform destroy
```

Confirm cleanup:
```bash
az group exists --name "$(terraform output -raw resource_group_name 2>/dev/null || echo rg-azfwidps-lab)"
```

## Official Microsoft Learn Sources

- Azure Firewall Premium features: https://learn.microsoft.com/en-us/azure/firewall/premium-features
- Azure Firewall threat intelligence: https://learn.microsoft.com/en-us/azure/firewall/threat-intel
- Azure Firewall threat intelligence settings: https://learn.microsoft.com/en-us/azure/firewall-manager/threat-intelligence-settings
- Azure Firewall IDPS signature rule categories: https://learn.microsoft.com/en-us/azure/firewall/idps-signature-categories
- Azure Firewall rule processing logic: https://learn.microsoft.com/en-us/azure/firewall/rule-processing
- Azure Firewall logs and metrics: https://learn.microsoft.com/en-us/azure/firewall/logs-and-metrics
