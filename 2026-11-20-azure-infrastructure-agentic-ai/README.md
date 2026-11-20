# Azure infrastructure for agentic AI (preview)

Terraform practice lab for the Azure New Features video **Azure Infrastructure for Agentic AI: Sandboxes and Agent Grid (Preview) | Azure New Features** (playlist **azure new features**, Network Technician channel).

Microsoft published [Azure Infrastructure for Agentic AI](https://techcommunity.microsoft.com/blog/azurecompute/azure-infrastructure-for-agentic-ai/4574616) around Ignite, dated 18–19 November 2026. The foundation it describes is **preview** capability on Azure Container Instances serverless sandboxes, with optional **limited preview** Agent Grid networking and Microsoft Entra Agent ID. This lab practices the **virtual-network lane**: a delegated sandbox subnet, NSGs, NAT egress, private storage, identity, and monitoring. It does not deploy GPU SKUs or Azure OpenAI.

This lab does **not** repeat earlier lessons:

- [AI Security add-on for Azure Firewall Premium](https://www.youtube.com/watch?v=b54n4b9-PNQ) — [lab](../2026-11-19-firewall-ai-security)
- [Azure DDoS Custom Policy GA](https://www.youtube.com/watch?v=66Jcp5MDQgM) — [lab](../2026-11-17-azure-ddos-custom-policy)
- [Azure DDoS Peacetime Telemetry](https://www.youtube.com/watch?v=gfqZXnci0Eg) — [lab](../2026-11-20-ddos-peacetime-telemetry)

## Cost warning

This lab creates a **Standard NAT gateway** and public IP, a storage account, a private endpoint, private DNS, and a Log Analytics workspace. Those have ongoing charges even though the default apply has **no virtual machines, no GPU SKUs, and no Azure OpenAI**.

An AI agents group, once you create it outside Terraform, also provisions a **managed resource group and snapshot storage account** in your subscription. Microsoft’s article states that sandbox compute is billed only while running, not while hibernated, and that storage and other services follow their usual charges. Treat that billing statement as **Microsoft-reported** from the article, and confirm current [Azure Container Instances pricing](https://azure.microsoft.com/pricing/details/container-instances/) before you rely on it.

**Review current pricing before you apply. Run `terraform destroy` when you finish.** Do not leave this lab running. Do not add GPU SKUs to the default configuration.

## What it builds

| Piece | Why it matters |
| --- | --- |
| Resource group and virtual network | A narrow scope you can create and destroy as a unit. Address spaces are illustrative teaching values. |
| Subnet `snet-sandbox` (delegation added after apply) | Official virtual-network tutorial: each sandbox in the group gets a private IP from this subnet; the group network profile cannot be changed after create. `azurerm` 5.14.0 cannot set the official `Microsoft.ContainerInstance/AIAgentsGroups` delegation, so you add it with CLI or ARM after apply. |
| Standard NAT gateway and public IP on the sandbox subnet, with `default_outbound_access_enabled = true` | Official tutorial pattern for outbound internet access from a VNet-connected group. |
| NSG on the sandbox subnet | Official docs: isolation depends on the delegated subnet; use an NSG to allow or deny traffic in either direction. The rules here are a starting lab posture, not a production pack. |
| User-assigned managed identity | Official agent-identity tutorial uses this identity on the AI agents group for federated exchange to an Entra Agent ID. |
| Storage account (no public network access), private blob endpoint, and `privatelink.blob.core.windows.net` | Private artifacts and state; reachability only, not authorization. |
| Log Analytics workspace | Optional log destination. It is not required to create the network surround. |

The default apply does **not** create an AI agents group, a sandbox, Agent Grid, or an Entra Agent ID. Those are preview objects with provider and access gaps, documented below.

## Honest limits: not in azurerm yet

Checked against `hashicorp/azurerm` **5.14.0**. There is still **no** first-class AzureRM resource for:

- `Microsoft.ContainerInstance/aiAgentsGroups` (serverless sandboxes / AI agents group)
- Azure Agent Grid (internally also referred to as Agent Fabric in some ARM, CLI, and API names)
- Microsoft Entra Agent ID blueprints and agent identities

The provider also **rejects** the official subnet delegation name `Microsoft.ContainerInstance/AIAgentsGroups` (it is not in the 5.14.0 allow-list). This lab therefore creates `snet-sandbox` **without** that delegation and documents the CLI / ARM step below.

This lab does not invent missing resources and does not add the AzAPI provider. Microsoft documents [AI agents groups in ARM, Bicep, and AzAPI](https://learn.microsoft.com/en-us/azure/templates/microsoft.containerinstance/2026-08-01-preview/aiagentsgroups) (`2026-08-01-preview`, with a later `2026-09-01-preview` also published). If you later use AzAPI on your own, that is outside this lab’s default apply.

### After apply: create an AI agents group (ARM / REST)

Prerequisites, from official docs:

1. Register `Microsoft.ContainerInstance` (`az provider register --namespace Microsoft.ContainerInstance --wait`).
2. Request quota: Azure portal support request, quota type **Container Instances**, then **AIAgentsGroups - StandardCores (Preview)** for your region.
3. Assign the documented roles (**Contributor**, **Azure Deployment Stack Owner**, and **Storage Blob Data Contributor**) to the **Compute Sandbox Groups** service principal on the subscription, so the service can create the managed resource group and snapshot storage account. Official tutorials show how to resolve that service principal. Role assignments can take up to 15 minutes.
4. Confirm the region still supports serverless sandboxes.

Then create the group with the delegated subnet from `terraform output -raw sandbox_subnet_id`. Official tutorial API version is `2026-08-01-preview`. Do **not** attach Agent Grid to this VNet-integrated group during the current limited preview (see the composition warning below).

```http
PUT https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/rg-agentic-ai-infra-lab/providers/Microsoft.ContainerInstance/AIAgentsGroups/{groupName}?api-version=2026-08-01-preview
Content-Type: application/json

{
  "location": "centralus",
  "identity": {
    "type": "UserAssigned",
    "userAssignedIdentities": {
      "{group_identity_id}": {}
    }
  },
  "properties": {
    "identityProfile": {
      "federatedIdentityCredential": "{group_identity_principal_id}"
    },
    "networkProfile": {
      "subnets": [
        { "id": "{sandbox_subnet_id}" }
      ]
    }
  }
}
```

Wait until `properties.provisioningState` is `Succeeded`. Then use the group `connect` action to get the sandbox management endpoint and a short-lived token, and create sandboxes with the sandbox management API, as in [Quickstart: Create your first serverless sandbox](https://learn.microsoft.com/en-us/azure/container-instances/container-instances-ai-sandboxes-quickstart) and [Connect sandboxes to a virtual network](https://learn.microsoft.com/en-us/azure/container-instances/container-instances-ai-sandboxes-tutorial-virtual-network).

Replace `{group_identity_id}` and `{group_identity_principal_id}` with the Terraform outputs of the same names. Grant **Storage Blob Data Contributor** (or a narrower role) on the storage account to the **Entra Agent ID**, then assign that agent identity to the sandbox that should use it. Official tutorials show that a sandbox without an agent identity cannot obtain a token, even in a group that has this managed identity attached.

### Agent Grid (limited preview) is a different lane

Official Agent Grid docs say **ACI sandbox groups are supported only with a public IP address** in this limited preview, and that **sandbox groups that use virtual network integration are not supported with Agent Grid**. This lab is the VNet-integration lane, so it does **not** create or attach a grid.

If you want to evaluate Agent Grid instead:

1. Request access with the limited-preview form linked from [What is Azure Agent Grid?](https://learn.microsoft.com/en-us/azure/agent-grid/overview).
2. Use a supported region from that article (at the time this lab was written: Central US, West US 2, Sweden Central, Australia East, and Indonesia Central).
3. Follow [Configure Azure Agent Grid](https://learn.microsoft.com/en-us/azure/agent-grid/configure-agent-grid) and [Control serverless sandbox outbound traffic with Agent Grid](https://learn.microsoft.com/en-us/azure/container-instances/container-instances-ai-sandboxes-tutorial-agent-grid).
4. Do not attach that grid to the VNet-integrated group this lab prepares, until Microsoft documents that composition.

In this preview, Agent Grid workload identities are **not** connected to Microsoft Entra Agent ID.

## Prerequisites

An Azure subscription, `az login`, Terraform 1.6 or later, provider `hashicorp/azurerm` 5.14.0, and rights to create a virtual network, delegated subnet, NAT gateway, public IP, NSG, user-assigned identity, storage account, private endpoint, private DNS zone, and Log Analytics workspace in one resource group.

Serverless sandboxes, Agent Grid, and Entra Agent ID are **preview** features. Preview features are excluded from ordinary SLAs and may change. See the [Supplemental Terms of Use for Microsoft Azure Previews](https://azure.microsoft.com/support/legal/preview-supplemental-terms/).

## Steps

```bash
az login
cp terraform.tfvars.example terraform.tfvars
# set subscription_id and unique_suffix (3-8 lowercase letters or numbers)
terraform init
terraform plan
terraform apply
```

Then, in the Azure portal or with Azure CLI / REST:

1. Add the official subnet delegation, which `azurerm` 5.14.0 cannot set:

   ```bash
   az network vnet subnet update      --resource-group rg-agentic-ai-infra-lab      --vnet-name "$(terraform output -raw virtual_network_name | sed 's/"//g')"      --name snet-sandbox      --delegations Microsoft.ContainerInstance/AIAgentsGroups
   ```

   Use the actual virtual network name from `terraform output virtual_network_name`. Confirm the NAT gateway is associated and the NSG is attached.
2. Confirm the storage account has public network access disabled and that the blob private endpoint and private DNS zone are in place.
3. Note `sandbox_subnet_id`, `group_identity_id`, and `group_identity_principal_id`.
4. If you will create a sandbox, complete the quota and service-principal steps above, then create the AI agents group with ARM or REST. Do not expect an `azurerm` resource to do that in 5.14.0.
5. If you assign an Entra Agent ID to a sandbox, grant data-plane access on the storage account to **that** identity, then test reachability of the private blob endpoint from the sandbox separately from authorization.

If sandbox create or connect fails after you tighten the NSG further, review current ACI sandbox networking guidance before you assume the platform path is broken. The starting rules in this lab deny inbound internet and allow virtual-network and load-balancer inbound, plus virtual-network and internet outbound through the NAT gateway.

## Rollback and cleanup

```bash
terraform destroy
```

If you created an AI agents group outside Terraform, **delete the group first** and wait until that long-running operation finishes. Official docs say you cannot delete a subnet while an AI agents group still uses it. Then run `terraform destroy`. Destroying the resource group removes the virtual network, NAT gateway, NSG, identity, storage account, private endpoint, private DNS, and workspace. Snapshots in a service-managed resource group may need a separate cleanup if you created a group.

## Notes

- Address spaces are illustrative teaching values, not production recommendations.
- This lab is the VNet-integration lane. It is not an Agent Grid lab, and it is not the Azure Firewall AI Security add-on lab.
- Confidential ACI sandboxes that use a confidential computing enforcement policy are documented as incompatible with Agent Grid and with virtual network integration in current Microsoft Learn content.
- Narration in the companion video is a synthetic voice generated offline.
