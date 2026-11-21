# Terraform Practice Lab: Azure DDoS Network Protection (`2026-11-21-azure-ddos-network-protection`)

This Terraform lab provisions the core Azure DDoS Network Protection building blocks covered in the lesson:
- `azurerm_network_ddos_protection_plan` — creates the tenant-wide DDoS Network Protection plan.
- `azurerm_virtual_network` — associates the Hub VNet with the DDoS Protection Plan via the `ddos_protection_plan` block.
- `azurerm_public_ip` — creates a Standard SKU Public IP for an edge resource (e.g., Application Gateway or Azure Firewall).
- `azurerm_log_analytics_workspace` + `azurerm_monitor_diagnostic_setting` — routes `DDoSProtectionNotifications`, `DDoSMitigationFlowLogs`, and `AllMetrics` to Log Analytics.
- `azurerm_monitor_metric_alert` — fires a Severity 1 alert whenever `IfUnderDDoSAttack > 0`.

## Usage
```bash
terraform init
terraform validate
terraform plan
```

> **Cost Warning:** Azure DDoS Network Protection carries a substantial flat monthly base fee (covering up to 100 protected public IPs). Always run `terraform destroy` immediately after testing in a sandbox subscription.

## Honest `azurerm` Provider Gaps
The following Azure DDoS Network Protection capabilities are **not** managed through `azurerm` Terraform resources and remain Azure Portal / Microsoft Support / Partner workflows:
1. **DDoS Rapid Response (DRR) Engagement:** Opening a DRR incident ticket during an active attack is performed through Azure Support, not Terraform.
2. **DDoS Cost Protection Claims:** Requesting scale-out resource credits after a documented attack is an Azure Billing/Support workflow.
3. **Attack Simulation Testing:** Running controlled DDoS simulations requires onboarding through Microsoft-approved partners (MazeBolt, Red Button and RedWolf).
4. **DDoS Mitigation Reports (`DDoSMitigationReports`):** Note that Microsoft announced retirement/deprecation of the legacy `DDoSMitigationReports` diagnostic log category starting mid-2026; use `DDoSProtectionNotifications`, `DDoSMitigationFlowLogs`, and Azure Monitor metrics instead.
5. **Peacetime Telemetry (Preview):** Enabling preview peacetime telemetry features may require subscription feature registration outside standard `azurerm` attributes.
