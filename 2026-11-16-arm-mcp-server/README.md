# ARM MCP at Ignite 2026: query, plan, act, and verify an NSG change

Terraform practice lab for the Azure New Features video "ARM MCP at Ignite 2026: Query, Plan, Act and Verify an NSG Change" (YouTube playlist **azure new features**, Network Technician channel).

On 13 November 2026, ahead of Ignite, Microsoft expanded the Azure Resource Manager (ARM) MCP server from query-and-experiment toward a query, plan, act, and verify workflow on the Azure control plane. This lab gives you a real network change to preview, deploy, and verify. It is not a Virtual Network Manager or security admin rules lab, and it does not use Front Door or Application Gateway.

The lab does not install the ARM MCP server. Terraform builds the starting network. A Bicep file is the change. Azure CLI what-if, deploy, and show commands are the hands-on stand-ins for `whatif_deployment`, `create_deployment`, `get_deployment_status`, and `get_resource`.

## What it builds

| Piece | Why it matters |
| --- | --- |
| Resource group, virtual network, and one subnet | A narrow scope you can grant to a signed-in user or an agent |
| NSG with `DenySshFromInternet` at priority 200, associated to the subnet | The starting posture: SSH from the internet is denied |
| `nsg-management-ssh.bicep` | Adds `AllowSshFromManagement` at priority 100 from a management prefix you set |

## MCP tool mapping

| You run | ARM MCP tool it stands in for |
| --- | --- |
| Inventory in the portal or `az network nsg list` | Resource Graph `generate_query` / `execute_query` |
| `az deployment group what-if` | `whatif_deployment` |
| `az deployment group create` | `create_deployment` |
| `az deployment group show` | `get_deployment_status` |
| `az network nsg show` | `get_resource` |

In an agent session, author and build the Bicep with the Bicep MCP server, then preview and deploy with the ARM MCP server. Review a what-if result before you approve a deployment. A preview does not grant permissions and does not guarantee that the later deployment succeeds.

## Prerequisites

An Azure subscription, `az login`, Terraform 1.6+, provider `hashicorp/azurerm` 5.14.0, and rights to create a virtual network and NSG in one resource group.

## Cost warning

The virtual network, subnet, and NSG have no compute and no public IP address. You still pay nothing material if you destroy the lab when you finish, but an idle resource group with a VNet is not an excuse to leave it up. **Run `terraform destroy` when you finish.** If you already deployed the Bicep rule, destroying the resource group still removes it.

## Steps

```bash
az login
export ARM_SUBSCRIPTION_ID="your-subscription-id"
cp terraform.tfvars.example terraform.tfvars   # set resource_group_name and management_prefix
terraform init
terraform plan
terraform apply

# Plan: preview the NSG rule. Do not skip this.
az deployment group what-if \
  --resource-group "$(terraform output -raw resource_group_name)" \
  --template-file nsg-management-ssh.bicep \
  --parameters nsgName="$(terraform output -raw nsg_name)" \
               managementPrefix="$(terraform output -raw management_prefix)"

# Act: apply only after you have reviewed the preview.
az deployment group create \
  --resource-group "$(terraform output -raw resource_group_name)" \
  --name nsg-management-ssh \
  --template-file nsg-management-ssh.bicep \
  --parameters nsgName="$(terraform output -raw nsg_name)" \
               managementPrefix="$(terraform output -raw management_prefix)"

# Verify: both the priority 100 allow and the priority 200 internet deny should be present.
az network nsg show \
  --resource-group "$(terraform output -raw resource_group_name)" \
  --name "$(terraform output -raw nsg_name)" \
  --query securityRules
```

Replace `192.0.2.0/24` with a management prefix you actually own before you treat this as anything but a documentation exercise.

## Guardrails to practice

1. Use a resource group scope, not the subscription, for the signed-in account that would call the ARM MCP tools.
2. Always run what-if before create. Template what-if is not a preview of a direct `create_or_update_resource` call.
3. A prompt such as "do not change production" is not an authorization boundary. Azure RBAC and policy are.
4. `execute_resource_action` is not used in this lab, but those POST actions can return keys. Treat tool results that include secrets as sensitive.

## Experiments

1. Change `management_prefix` and run what-if again. Confirm the preview shows a modify of the allow rule, not a new internet allow.
2. Run `az deployment group show --resource-group ... --name nsg-management-ssh` and map it to `get_deployment_status`.
3. After a successful deploy, run what-if again and confirm it reports no change for the same parameters.
4. If you use the ARM MCP server itself, keep Skills off unless you opt in with the `x-mcp-toolset: Skills` header. Skills are experimental and off by default in the public preview.

Destroy with `terraform destroy`.

## Sources

- https://techcommunity.microsoft.com/blog/AzureGovernanceandManagementBlog/what%E2%80%99s-new-in-the-azure-resource-manager-mcp-server-at-ignite-2026/4571824
- https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-resource-manager-mcp-overview
- https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-resource-manager-mcp-tools
- https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-resource-manager-mcp-governance
- https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-resource-manager-mcp-skills
