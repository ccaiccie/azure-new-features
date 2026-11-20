# Azure DDoS Protection peacetime telemetry (public preview)

Terraform practice lab for the Azure New Features video **Azure DDoS Protection Peacetime Telemetry (Public Preview) | Azure New Features** (playlist **azure new features**, Network Technician channel).

Peacetime telemetry, announced 19 November 2026 (Azure Update [AZ581175](https://mc.merill.net/message/AZ581175)), is a **public preview**. For eligible public IP addresses protected by DDoS Network Protection or DDoS IP Protection, the existing DDoS traffic metrics — including Inbound packets DDoS, Inbound TCP packets DDoS, Inbound SYN packets DDoS, Inbound UDP packets DDoS, and Inbound other packets DDoS — show data during normal operation, not only while mitigation is active. There are no new metric names and no registration. Protection and mitigation behavior do not change.

This lab is not the earlier [DDoS custom policy lab](../2026-11-17-azure-ddos-custom-policy). That lesson covers fixed TCP, UDP, and SYN detection thresholds. Use peacetime metrics from this lab to choose those thresholds; do not repeat that deployment here.

## Cost warning

This lab **enables Azure DDoS Network Protection** by creating a DDoS protection plan and associating it with the virtual network. That is a paid SKU with a **material monthly charge**, plus Standard public IP, Standard Load Balancer, Log Analytics ingestion, and Azure Monitor alert-rule charges. Peacetime telemetry itself has no additional DDoS charge beyond existing DDoS Protection pricing.

**Review [Azure DDoS Protection pricing](https://azure.microsoft.com/pricing/details/ddos-protection/) before you apply. Run `terraform destroy` when you finish.** Do not leave this lab running.

## What it builds

| Piece | Why it matters |
| --- | --- |
| Resource group, virtual network, and one subnet | A narrow scope you can create and destroy as a unit |
| DDoS protection plan, enabled on the virtual network | Network Protection so eligible public IPs in the VNet are protected |
| Standard public IP on a Standard Load Balancer frontend, empty backend, no virtual machines | The public IP is associated with a resource in the protected VNet, which is what peacetime telemetry requires |
| Log Analytics workspace and diagnostic settings on the public IP | Optional export of DDoS flow logs, protection notifications, and supported metrics. **You do not need this workspace to view peacetime platform metrics.** |
| Action group, plus metric alerts | An attack-status alert on `IfUnderDDoSAttack`, and placeholder traffic-condition alerts on `PacketsInDDoS`, `TCPPacketsInDDoS`, and `SYNPacketsInDDoS` |

The default traffic-alert thresholds (50,000 TCP pps, 5,000 SYN pps, 50,000 aggregate pps) are **placeholders**, not recommended production values. After apply, watch peacetime metrics on the public IP and replace them from your own baseline.

## Honest limit: custom policy thresholds are not in azurerm yet

Checked against `hashicorp/azurerm` **5.14.0**. There is still **no** native `azurerm_network_ddos_custom_policy` resource (open provider pull requests 33232 and 33233 at the time this lab was written). This lab does not invent that resource and does not deploy a custom policy.

If you want a fixed inbound TCP, UDP, or TCP SYN packets-per-second detection threshold after you have a peacetime baseline:

1. Azure portal: search for **DDoS custom policies**, create a policy, add a protocol rule, and associate it with the supported public endpoint.
2. Azure CLI (GA command group): `az network ddos-custom-policy create` / `update`, then associate it with the supported resource as shown in current CLI help.
3. ARM / REST: `Microsoft.Network/ddosCustomPolicies`, as used in the [2026-11-17-azure-ddos-custom-policy](../2026-11-17-azure-ddos-custom-policy) lab.

When you set a custom threshold for a protocol, automatic tuning is disabled for that protocol only. Base the number on measured peacetime peaks plus headroom, stay inside the valid range for that protocol, and validate in a non-production environment. The earlier custom policy video is [Azure DDoS Custom Policy GA: Fixed TCP, UDP and SYN Thresholds](https://www.youtube.com/watch?v=66Jcp5MDQgM).

## Prerequisites

An Azure subscription in the **Azure public cloud**, `az login`, Terraform 1.6 or later, provider `hashicorp/azurerm` 5.14.0, and rights to create a DDoS protection plan, virtual network, public IP, load balancer, Log Analytics workspace, diagnostic settings, action group, and metric alerts in one resource group.

During the preview, peacetime telemetry is documented for the Azure public cloud, for IPv4 and IPv6 public IP addresses. It is not available in sovereign clouds such as Azure Government. Protection alone does not establish preview eligibility for every region, cloud, or IP version. Confirm current guidance in [Monitor Azure DDoS Protection](https://learn.microsoft.com/en-us/azure/ddos-protection/monitor-ddos-protection) and the [Supplemental Terms of Use for Microsoft Azure Previews](https://azure.microsoft.com/support/legal/preview-supplemental-terms/).

## Steps

```bash
az login
cp terraform.tfvars.example terraform.tfvars
# set subscription_id, and optionally alert_email
terraform init
terraform plan
terraform apply
```

Then, in the Azure portal:

1. Open the public IP from `terraform output public_ip_name`.
2. Under **Monitoring**, select **Metrics**. Confirm the scope is that public IP.
3. Set a recent time range and **Time granularity** to 1 minute.
4. Add **Inbound TCP packets DDoS**, **Inbound UDP packets DDoS**, and **Inbound SYN packets DDoS**, each with **Max** aggregation. These metrics already report packets per second; do not divide by 60.
5. Add a **separate** chart for **Under DDoS attack or not**, also Max. During normal operation the traffic charts can contain data while this status metric reports 0.
6. Compare the packet rates with **Inbound TCP packets to trigger DDoS mitigation**, **Inbound UDP packets to trigger DDoS mitigation**, and **Inbound SYN packets to trigger DDoS mitigation**. Those trigger metrics report policy thresholds, not observed traffic.
7. Replace the placeholder traffic-alert thresholds (`tcp_packets_alert_threshold_pps`, `syn_packets_alert_threshold_pps`, `inbound_packets_alert_threshold_pps`) from the peaks you actually see, then `terraform apply` again.

Missing data is not the same as zero. If no points appear, check preview eligibility, public-IP scope, permissions, the time range, and reporting delay. Do not generate an attack to make metrics appear. Viewing these platform metrics does not require the Log Analytics workspace.

A traffic-condition alert can fire while **Under DDoS attack or not** stays at 0. That alert does not change mitigation. Keep the `IfUnderDDoSAttack >= 1` alert as the attack-status signal. Review any older workbook or automation that treated the presence of DDoS traffic data as an attack.

## How to pick thresholds

1. Collect peacetime TCP, SYN, UDP, and aggregate packet rates on this public IP over days and weeks, including busy periods.
2. Chart those rates next to the three mitigation-trigger metrics.
3. For a **traffic-condition alert**, set a packets-per-second value above normal peaks and below a level that would be noise. Do not copy the attack-status threshold of 1 onto a rate metric.
4. For a **custom policy** fixed threshold, use the same measured peaks plus planned headroom, inside the valid range for that protocol, then set the policy outside Terraform as described above. Validate in a non-production environment.

## Diagnostic logs

The diagnostic setting sends `DDoSMitigationFlowLogs` and `DDoSProtectionNotifications` to Log Analytics, and exports supported metrics. Peacetime telemetry does **not** change when those logs or notifications are produced: they are still tied to mitigation and protection events, not to everyday traffic charts.

The `DDoSMitigationReports` category is omitted on purpose. Microsoft retired that diagnostic category starting around mid-August 2026 and documented new fields on `DDoSMitigationFlowLogs`. See [DDoS Mitigation Reports](https://learn.microsoft.com/en-us/azure/ddos-protection/ddos-response-strategy) and the monitoring data reference for current schema guidance.

## Rollback and cleanup

```bash
terraform destroy
```

Destroying the resource group removes the protection plan, virtual network, public IP, load balancer, workspace, diagnostic setting, action group, and alerts. That is the rollback for this lab.

## Notes

- Metric display names and REST API names used here come from [Monitor Azure DDoS Protection monitoring data reference](https://learn.microsoft.com/en-us/azure/ddos-protection/monitor-ddos-protection-reference).
- With Maximum aggregation, a displayed 1 on **Under DDoS attack or not** means at least one reported value in the interval or lookback was 1, not necessarily that an attack is still active when you view the chart or the notification.
- Incoming, forwarded, and dropped maximums may not add up, because their peaks can occur at different times. Dropped data alone does not prove an attack. Forwarded traffic does not prove successful application delivery.
- Address spaces and placeholder alert thresholds are illustrative teaching values, not production recommendations.
