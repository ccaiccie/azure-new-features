# Azure Route Server IPv4/IPv6 dual-stack

Terraform practice lab for this video: https://youtu.be/NUKO-59xYtk

## Goals

- Create a dual-stack virtual network and a `RouteServerSubnet` that already has both an IPv4 prefix and an IPv6 /64, matching Microsoft's dual-stack tutorial
- Deploy Azure Route Server into that subnet so it can be created in dual-stack mode
- Leave a second dual-stack subnet you can use later for an NVA BGP peer

## Prerequisites

- An Azure subscription and the `az` CLI (`az login`) plus `terraform` 1.6+
- A contributor role on the subscription or a resource group where you can create the lab resources

- Dual-stack Route Server is public preview, limited to documented regions, and requires preview access on the subscription. The default location is `westcentralus`. If apply fails with a region or feature-registration error, register the preview or pick another region from the list in the lesson.

## Cost warning

Azure Route Server is billed per hour while it exists (two routing infrastructure units is the documented minimum). This lab does not create a virtual machine or a VPN/ExpressRoute gateway, but the Route Server itself is not free. Destroy it as soon as you have confirmed Dual Stack Mode.

## What this lab cannot provision

azurerm 5.14.0's `azurerm_route_server` resource has no `dual_stack_mode` (or equivalent) argument. Microsoft's documentation says that if `RouteServerSubnet` already has an IPv6 /64 when you create the Route Server, Dual Stack Mode is enabled at creation. This lab relies on that documented behavior and does not invent a provider flag.

If the portal still shows Dual Stack Mode as Disabled after apply, enable it in the portal or with the documented PowerShell/CLI. That change is irreversible and can take up to 40 minutes.

This lab does not deploy an NVA, ExpressRoute, VPN gateway, or dual-stack route maps.

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
az network routeserver show --resource-group rg-routeserver-dualstack-lab --name rsdual-rs
az network vnet subnet show --resource-group rg-routeserver-dualstack-lab --vnet-name rsdual-vnet --name RouteServerSubnet --query addressPrefixes
```

In the Azure portal, open the Route Server, go to Configuration, and confirm Dual Stack Mode is Enabled. Also confirm `RouteServerSubnet` lists both the IPv4 /26 and the IPv6 /64.

## Cleanup

Destroy the lab when you are finished so you are not billed for idle resources:

```bash
terraform destroy
```

Confirm in the Azure portal that the resource group is gone.
