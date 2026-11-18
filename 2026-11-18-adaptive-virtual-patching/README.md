# Azure Adaptive Virtual Patching: an AI shield between disclosure and the patch

Terraform practice lab for the Azure New Features video "Azure Adaptive Virtual Patching: an AI Shield Between Disclosure and the Patch" (YouTube playlist **azure new features**, Network Technician channel).

Azure Adaptive Virtual Patching was announced at Microsoft Ignite on November 17, 2026 and is in **public preview**. It is an AI-orchestrated "adaptive shield" that applies targeted, **temporary** mitigations, network-based controls (including inline intelligence) and eBPF-based runtime enforcement on the workload (Tetragon policies deployed by a *neuron* extension), while you test and deploy the real patch. It does **not** install patches; mitigations can be rolled back after the patch is deployed and remediation is confirmed. The initial workload focus is **Linux VMs and Virtual Machine Scale Sets**; Windows is planned later.

## Important: what Terraform can and cannot do here

As of November 18, 2026 the `hashicorp/azurerm` provider (5.14.0) has **no resource for Adaptive Virtual Patching**, and the announcement does not publish an extension publisher/type for the neuron extension. This lab therefore does **not** try to create the service, its protected resources or its extension. It builds the realistic surroundings: two Linux targets (a VM and a scale set) with real network exposure, so that you can

1. onboard them as protected resources through the preview experience if your subscription has access, and
2. practise the same *mitigate → patch → confirm → roll back* lifecycle by hand with a temporary NSG rule (a manual network-layer compensating control, **not** the service).

## What it builds

| Piece | Why it matters |
| --- | --- |
| VNet `10.90.0.0/16`, subnets `snet-vm` and `snet-vmss` (default outbound access off) | Two workload subnets, explicit outbound only |
| NAT gateway + Standard public IP on both subnets | Outbound path for package updates and patches |
| One NSG on both subnets: SSH, 80 and the demo port only from `allowed_source_cidr`; LB probe allowed | The exposure paths: what is reachable, from where |
| Ubuntu 24.04 VM with a public IP, nginx on 80 and a stand-in "legacy" service on 8080, `patch_assessment_mode = "AutomaticByPlatform"` | Target 1 (Linux VM); platform patch assessment shows missing updates |
| Ubuntu 24.04 scale set (2 instances, `upgrade_mode = "Manual"`) behind a Standard Load Balancer with rules for 80 and 8080 | Target 2 (Linux VMSS) |
| `temporary_mitigation_enabled` → priority-100 NSG **deny** for `mitigation_port` | Manual practice of a temporary network mitigation and its rollback |

## Prerequisites

An Azure subscription, `az login`, Terraform 1.6+, provider `hashicorp/azurerm` 5.14.0, an SSH key pair, and your public IP (`curl -s https://ifconfig.me`). Check that `Standard_D2s_v5` is available in your region. For the optional onboarding step you need access to the Adaptive Virtual Patching public preview; follow Microsoft's preview instructions, which are not reproduced here.

## Cost warning

One VM, two scale set instances, a Standard Load Balancer, a NAT gateway and three Standard public IPs are billed while the lab exists. **Run `terraform destroy` when you finish.**

## Steps

```bash
cp terraform.tfvars.example terraform.tfvars   # subscription, your /32, SSH public key
terraform init
terraform validate
terraform plan
terraform apply
terraform output test_commands
curl -s http://$(terraform output -raw vm_public_ip):8080    # "legacy service on 8080 ..."
curl -s http://$(terraform output -raw lb_public_ip):8080    # answered by a scale set instance
```

## Exercises

1. **Identify affected workloads.** Run a patch assessment and list what is missing:
   `az vm assess-patches -g rg-avp-lab -n avp-vm-web`. On the VM and an instance, list what is *running* and *listening* (`systemctl list-units --type=service --state=running`, `ss -ltnp`). The announcement's point: an installed package is only part of exposure; running, used and reachable matters.
2. **Apply a temporary network mitigation.** Pretend a new CVE affects the service on 8080. Set `temporary_mitigation_enabled = true`, `terraform apply`, and confirm both `curl` tests to 8080 now time out while port 80 still works.
3. **Patch.** Install updates on the VM (`az vm install-patches -g rg-avp-lab -n avp-vm-web --maximum-duration PT1H --reboot-setting IfRequired --classifications-to-include-linux Critical Security`) and on the scale set instances (for example with `sudo apt-get update && sudo apt-get -y upgrade` over SSH, or `az vmss run-command invoke`). Re-run the assessment to confirm.
4. **Roll back.** Set `temporary_mitigation_enabled = false`, `terraform apply`, and confirm 8080 answers again. That is the mitigate → patch → confirm → roll back lifecycle.
5. **Optional, preview access only.** Onboard `avp-vm-web` and `avp-vmss-web` as protected resources (`terraform output vm_id`, `terraform output vmss_id`) and compare what the service reports with what you found in step 1.

## References

- The patch window is closing. Put time back on the defender's side (Azure Networking Blog, Nov 17, 2026): https://techcommunity.microsoft.com/blog/azurenetworkingblog/the-patch-window-is-closing-put-time-back-on-the-defender%E2%80%99s-side-/4573402
- Azure update AZ580689, Public Preview: Azure Adaptive Virtual Patching (Nov 17, 2026)
- Microsoft Ignite 2026 Book of News: https://news.microsoft.com/events/ignite/2026/book-of-news/
- azurerm `linux_virtual_machine` (`patch_assessment_mode`): https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine
- azurerm `linux_virtual_machine_scale_set`: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine_scale_set
