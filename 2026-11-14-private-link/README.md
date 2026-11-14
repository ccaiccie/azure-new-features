# Azure Private Link: private endpoint, DNS, and Private Link Service

Terraform practice lab for this video: https://youtu.be/lCTwyGjignE

## Goals

- Create a storage account that is not reachable on the public internet, a private endpoint for the blob subresource, and the `privatelink.blob.core.windows.net` private DNS zone linked to the virtual network
- Enable network policies on the private endpoint subnet, as covered in the lesson
- Create a provider-side Private Link Service in front of an internal Standard Load Balancer (no virtual machines)
- Optionally set `ip_version_type` to try Private Link over IPv6 or DualStack (preview)

## Prerequisites

- An Azure subscription and the `az` CLI (`az login`) plus `terraform` 1.6+
- A contributor role on the subscription or a resource group where you can create the lab resources

## Cost warning

This lab is relatively cheap: a Standard LRS storage account, a Standard internal load balancer, private DNS zones, and private endpoints. There are no virtual machines. You still pay small hourly or capacity charges while the load balancer and endpoints exist. Destroy the resource group when you finish.

## What this lab cannot provision

Private Link Service Direct Connect (public preview) and network security perimeter (GA) are not declared in this lab. azurerm 5.14.0 does not document a Direct Connect argument on `azurerm_private_link_service`. If you want to experiment with IPv6, set `ip_version_type` and follow the provider requirements (dual-stack address space, `private_endpoint_vnet_policies = Basic`, subnet `RouteTableEnabled`); this repo leaves those off by default so a standard IPv4 lab applies in any region.

DNS from on-premises through Azure DNS Private Resolver is described in the lesson but not deployed here.

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
az storage account show --resource-group rg-private-link-lab --name $(terraform output -raw storage_account_name) --query '{public:publicNetworkAccess,https:supportsHttpsTrafficOnly}'
az network private-endpoint show --resource-group rg-private-link-lab --name pllab-pe-blob --query '{ipVersion:ipVersionType,connection:privateLinkServiceConnections[0].privateLinkServiceConnectionState}'
az network private-link-service show --resource-group rg-private-link-lab --name pllab-pls --query alias
```

From a VM or Cloud Shell that uses this virtual network's DNS, a lookup of `$(terraform output -raw storage_account_name).blob.core.windows.net` should return the private endpoint address, not a public address. This lab does not create a VM, so run that lookup only if you already have a test VM in the virtual network.

## Cleanup

Destroy the lab when you are finished so you are not billed for idle resources:

```bash
terraform destroy
```

Confirm in the Azure portal that the resource group is gone.
