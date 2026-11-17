# Azure DDoS custom policy is generally available: fixed TCP, UDP and SYN thresholds

Terraform practice lab for the Azure New Features video "Azure DDoS Custom Policy is Generally Available: Fixed TCP, UDP and SYN Thresholds" (YouTube playlist **azure new features**, Network Technician channel).

On 16 November 2026, Azure DDoS Protection custom policy became generally available. You can set fixed inbound packets-per-second detection thresholds for TCP, UDP, and TCP SYN on supported public endpoints, while protocols you do not define keep adaptive auto-tuning. This lab is not a Virtual Network encryption lab, not an ARM MCP lab, and not a Virtual Network Manager security admin rules lab.

The AzureRM provider version used here, 5.14.0, does not yet include a native `azurerm_network_ddos_custom_policy` resource. The lab deploys the generally available `Microsoft.Network/ddosCustomPolicies` resource with an ARM template, which is one of the supported management paths.

## What it builds

| Piece | Why it matters |
| --- | --- |
| Resource group, virtual network, and one subnet | A narrow scope you can create and destroy as a unit |
| Standard public IP and Standard Load Balancer with one public frontend | A supported association target for a custom policy |
| Empty backend pool, no virtual machines | You can inspect the policy without running a workload |
| ARM template with one inbound TCP SYN detection rule | Shows a protocol-specific override; TCP and UDP stay adaptive |

The default SYN threshold is 20,000 packets per second. That is an example inside the valid range of 1,000 to 100,000, not a recommended production value. Base any real threshold on measured traffic.

## Cost warning

This lab does **not** enable Azure DDoS Network Protection or DDoS IP Protection. Those are paid SKUs, and a DDoS Protection plan can be a material monthly charge. Custom policy is meant to work with a protected public IP, but this lab leaves protection off so you can practice policy creation without turning on a paid SKU by accident.

A Standard public IP and a Standard Load Balancer still have a small hourly cost. **Run `terraform destroy` when you finish.** Do not enable DDoS Protection on the public IP or virtual network unless you have reviewed current pricing and intend to pay for it.

## Prerequisites

An Azure subscription, `az login`, Terraform 1.6+, provider `hashicorp/azurerm` 5.14.0, and rights to create a virtual network, public IP, load balancer, and a `Microsoft.Network/ddosCustomPolicies` resource in one resource group.

## Steps

```bash
az login
export ARM_SUBSCRIPTION_ID="your-subscription-id"
cp terraform.tfvars.example terraform.tfvars   # set resource_group_name
terraform init
terraform plan
terraform apply

# Inspect the custom policy. TCP and UDP rules should be absent.
az network ddos-custom-policy show   --resource-group "$(terraform output -raw resource_group_name)"   --name "$(terraform output -raw custom_policy_name)"
```

The show command should report a `TcpSyn` detection rule at the threshold you set, associated with the load balancer frontend IP configuration.

## Experiments

1. In a non-production environment, add a TCP detection rule (valid range 50,000 to 2,000,000 packets per second) and leave UDP unset. Confirm adaptive auto-tuning remains in effect for UDP.
2. Change `tcp_syn_threshold_pps` and apply again. Watch DDoS telemetry only if you have also enabled a paid protection SKU and have traffic to observe.
3. Delete the custom policy or run `terraform destroy`. After the policy is gone, associated public IPs return to adaptive auto-tuning for every protocol.

## Rollback and cleanup

```bash
terraform destroy
```

Destroying the resource group removes the load balancer, public IP, virtual network, and the custom policy. That is the rollback for this lab.

## Notes

- Direction is inbound. Custom thresholds do not apply to outbound traffic.
- Generally available association is public-IP-centric in the portal and also supports virtual machines, virtual machine scale sets, Azure Kubernetes Service, Application Gateway, Azure Firewall, and Azure Bastion. This lab uses a Standard Load Balancer frontend, which remains a valid target.
- A same-day preview lets Azure DDoS Protection cover StandardV2 NAT Gateway public IPs. Custom policies are not part of that initial NAT Gateway preview, and this lab does not build it.
