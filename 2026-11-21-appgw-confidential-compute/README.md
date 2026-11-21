# Application Gateway Confidential Compute (preview)

Terraform practice lab for the Azure New Features lesson on Application Gateway Confidential Compute (public preview, announced 17 November 2026, Azure Update [AZ579649](https://azure.microsoft.com/updates?id=579649)).

Video: Upload pending

## Goals

- Deploy a Standard_v2 Application Gateway in a region that the Learn article lists for Confidential Compute (default: East US)
- Inspect the gateway, public IP, and subnet layout used in the lesson
- Compare that deployment with the documented create-time property `enableConfidentialCompute`

## Prerequisites

- An Azure subscription and the `az` CLI (`az login`) plus Terraform 1.6 or later
- A contributor role on the subscription or on a resource group where you can create the lab resources
- Confirm the region is still on the published list in [Application Gateway Confidential Compute overview](https://learn.microsoft.com/en-us/azure/application-gateway/confidential-compute-overview) before you apply. Preview region lists can change.

## Cost warning

Application Gateway Standard_v2 is billed for the time the gateway exists and for capacity units. This lab sets `min_capacity = 0` so it can scale to zero when idle, but creating the gateway and a Standard public IP still incurs charges. There is no backend virtual machine and no WAF in this lab. Destroy the resource group as soon as you finish.

## What this lab cannot provision

Application Gateway Confidential Compute must be enabled when the gateway is created. You cannot enable it on an existing gateway.

azurerm 5.14.0's `azurerm_application_gateway` resource does not document an `enable_confidential_compute` (or similar) argument. This lab does not invent that argument, and it does not apply a post-create update that Microsoft says is unsupported.

The lab therefore deploys a Standard_v2 Application Gateway *without* the Confidential Compute add-on. After apply, the gateway is useful for studying the surrounding resources. To create a gateway *with* the add-on, use the portal checkbox or a create call with API version `2026-05-01` or later and this property in the resource body:

```json
"enableConfidentialCompute": true
```

Example (do not run this against the already-created lab gateway; it will not turn the add-on on):

```bash
# Illustrated create-time property only. Use API version 2026-05-01 or later.
# See: https://learn.microsoft.com/en-us/azure/application-gateway/confidential-compute-overview
```

Supported SKUs in the article are Standard_v2 and WAF_v2. The add-on is an hourly charge on top of the usual fixed and capacity-unit charges. The feature is a public preview: no SLA, and it is not recommended for production.

## Steps

1. Copy the example variables and edit them if needed:

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
az network application-gateway show \
  --resource-group "$(terraform output -raw resource_group_name)" \
  --name appgwcc-appgw \
  --query "{sku:sku,location:location,enableConfidentialCompute:enableConfidentialCompute}"
```

Expect `sku` to show Standard_v2 in the chosen region. `enableConfidentialCompute` is expected to be absent or false on this lab gateway, because azurerm 5.14.0 cannot set the create-time add-on.

## Cleanup

Destroy the lab when you are finished so you are not billed for idle resources:

```bash
terraform destroy
```

Confirm in the Azure portal that the resource group is gone.

## Sources

- https://learn.microsoft.com/en-us/azure/application-gateway/confidential-compute-overview
- https://azure.microsoft.com/updates?id=579649
- https://mc.merill.net/message/AZ579649
