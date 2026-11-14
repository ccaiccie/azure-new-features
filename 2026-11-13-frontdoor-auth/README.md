# Azure Front Door Premium (mTLS and JWT lesson)

Terraform practice lab for this video: https://youtu.be/ID69JMBDR9o

## Goals

- Create an Azure Front Door Premium profile, endpoint, origin group, origin, and route
- Use the Premium SKU, which is the SKU that supports edge mTLS (GA) and the JWT authentication policy (public preview)
- Produce an endpoint hostname you can call after apply

## Prerequisites

- An Azure subscription and the `az` CLI (`az login`) plus `terraform` 1.6+
- A contributor role on the subscription or a resource group where you can create the lab resources

## Cost warning

Azure Front Door Premium has a substantial monthly base fee plus request and data-transfer charges. This is one of the more expensive labs in this set. Do not leave the profile running after you finish. Destroy it immediately. Standard_AzureFrontDoor is cheaper but does not support client mTLS, so this lab does not use that SKU.

## What this lab cannot provision

azurerm 5.14.0 (Microsoft.Cdn API 2026-10-01) does not have arguments for Front Door mutual TLS (client-certificate validation mode, Key Vault trusted root, SAN/CN list, OCSP) or for a Front Door authentication policy that validates JWTs. `azurerm_cdn_frontdoor_custom_domain` only exposes server TLS (certificate type, minimum version, cipher suites). This lab does not invent mTLS or JWT blocks.

After apply, configure mTLS and the preview JWT policy in the Azure portal or with an ARM/Bicep template that uses the documented properties. mTLS also requires a custom domain; this lab uses the default endpoint hostname so you do not have to delegate DNS first. Origin lockdown (so clients cannot bypass Front Door) is a change on the origin, not on the Front Door profile, and is not applied to `www.example.com`.

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
az afd profile show --resource-group rg-frontdoor-auth-lab --profile-name fdauthlab-afd
az afd endpoint list --resource-group rg-frontdoor-auth-lab --profile-name fdauthlab-afd -o table
curl -I "https://$(terraform output -raw endpoint_host_name)"
```

Confirm the SKU is `Premium_AzureFrontDoor`. Then, in the portal, open the profile and review the (preview) authentication policy and custom-domain mTLS settings — those still have to be set outside Terraform.

## Cleanup

Destroy the lab when you are finished so you are not billed for idle resources:

```bash
terraform destroy
```

Confirm in the Azure portal that the resource group is gone.
