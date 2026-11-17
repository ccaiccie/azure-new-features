# Azure Virtual Network encryption: DTLS between VMs, limits and proof

Terraform practice lab for the Azure New Features video "Azure Virtual Network Encryption: DTLS Between VMs, Limits and Proof" (YouTube playlist **azure new features**, Network Technician channel).

## What it builds

| Piece | Why it matters |
| --- | --- |
| Two VNets with `encryption { enforcement = "AllowUnencrypted" }` | Hosts encrypt private-to-private VM traffic in a DTLS tunnel; AllowUnencrypted is the only enforcement supported at GA |
| Regional VNet peering, both directions | VM-to-VM traffic across regional and global peering is encrypted |
| Optional Linux VMs, `Standard_D2s_v5`, Accelerated Networking on, no public IP | Encryption needs a supported size (all v5+ D/E series) and Accelerated Networking |
| Storage account + VNet flow logs (version 2) on each VNet | The flow encryption field proves it: `X` encrypted, `NX` and `NX_*` codes explain why not |

## Prerequisites

An Azure subscription, `az login`, Terraform 1.6+, provider `hashicorp/azurerm` 5.14.0. A Network Watcher must exist in the region (Azure normally creates `NetworkWatcher_<region>` in `NetworkWatcherRG`; adjust the two variables if yours differs). Check that `Standard_D2s_v5` is available to your subscription in the region.

## Cost warning

Two D2s_v5 VMs, their disks, flow logs and storage are billed while the lab exists. Set `create_vms = false` to build only the networks. **Run `terraform destroy` when you finish.**

## Steps

```bash
cp terraform.tfvars.example terraform.tfvars   # subscription, SSH public key
terraform init
terraform validate
terraform plan
terraform apply
az network vnet show -g rg-vnetenc-lab -n vnetenc-vnet-a --query encryption -o tsv   # True  AllowUnencrypted
```

Generate traffic between the VMs across the peering (for example with Azure Bastion or Run Command: `curl` or `ping` the other VM's private IP from `terraform output vm_private_ips`). Wait for the flow logs (about 10 minutes), download a blob from the flow log storage account and look at the flow encryption field of the flow tuples.

If you enabled encryption on a VNet that already had running VMs, **stop and start** (deallocate and start) those VMs first.

## Experiments

1. Stop/start one VM and watch for `NX_SW_NOT_READY` while it boots, then `X`.
2. Change `vm_size` to a size without Accelerated Networking support (and set `accelerated_networking_enabled = false`) and compare: the flow is allowed but shows `NX`.
3. Curl an internet address from a VM and confirm that flow is `NX` (encryption is private-to-private only).
4. Read the scenario table in the docs and decide whether this VNet could host a VPN gateway (it should not).

## References

- What is Azure Virtual Network encryption? — https://learn.microsoft.com/azure/virtual-network/virtual-network-encryption-overview
- Create a virtual network with encryption — https://learn.microsoft.com/azure/virtual-network/how-to-create-encryption
- Virtual network flow logs (flow encryption field) — https://learn.microsoft.com/azure/network-watcher/vnet-flow-logs-overview
