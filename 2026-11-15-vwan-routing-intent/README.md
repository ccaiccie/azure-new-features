# Virtual WAN routing intent (Internet and Private policies)

Terraform practice lab for the Network Technician lesson on Azure Virtual WAN routing intent.

Video: (link added when the video is published)

## Goals

- Deploy a Standard Virtual WAN and a Standard virtual hub
- Attach Azure Firewall (SKU AZFW_Hub) with a firewall policy
- Enable routing intent with both an Internet policy and a Private policy whose next hop is that firewall
- Connect a spoke virtual network so you can inspect effective routes after apply

## Prerequisites

- An Azure subscription and the `az` CLI (`az login`) plus `terraform` 1.6+
- A contributor role on the subscription or a resource group where you can create the lab resources, including Virtual WAN and Azure Firewall

## Cost warning

A Virtual WAN hub and Azure Firewall are billed for as long as they exist. This lab is for short practice only. There is no workload virtual machine, but the hub, the firewall, and the firewall's public IP still incur charges. Destroy the resource group as soon as you finish.

The firewall policy includes a single allow-all network rule so you can confirm that traffic is steered. Do not leave this policy in place for a real workload.

## Steps

1. Copy the example variables and edit them:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Initialize and review the plan:

   ```bash
   terraform init
   terraform plan
   ```

3. Apply only after you have read the cost warning:

   ```bash
   terraform apply
   ```

## Verify

```bash
terraform output
az network vhub routing-intent show \
  --resource-group rg-vwan-intent-lab \
  --vhub-name vwanlab-hub \
  --name vwanlab-intent
az network vnet show --resource-group rg-vwan-intent-lab --name vwanlab-spoke --query addressSpace
```

Expect the routing intent to list Internet and PrivateTraffic destinations with the Azure Firewall as next hop. After apply, you can also inspect effective routes from a test virtual machine you add in the spoke subnet; this lab does not create that virtual machine so that idle compute is not billed.

## Cleanup

Destroy the lab when you are finished so you are not billed for idle resources:

```bash
terraform destroy
```

Confirm in the Azure portal that the resource group is gone.
