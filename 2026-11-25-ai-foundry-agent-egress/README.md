# Practice Lab — Microsoft Foundry Agent Service Managed VNet & Approved Outbound Egress

Intended repository path: `ccaiccie/azure-new-features/2026-11-25-ai-foundry-agent-egress`

This Terraform and Azure CLI practice lab deploys a **Microsoft Foundry (AI Services)** account with a **Microsoft-managed virtual network** in **`AllowOnlyApprovedOutbound`** mode, assigns the **`Azure AI Enterprise Network Connection Approver`** role to the account's system-assigned managed identity, creates a managed private endpoint outbound rule to an Azure Storage account (`blob`), and optionally adds an FQDN outbound rule enforced by a managed Azure Firewall.

## Official Microsoft Learn Sources
- Networking options for Foundry Agent Service: https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/networking-options
- Configure managed virtual network for Microsoft Foundry: https://learn.microsoft.com/en-us/azure/foundry/how-to/managed-virtual-network
- Set up private networking for Foundry Agent Service: https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/virtual-networks
- Configure a private link / private endpoint for Foundry: https://learn.microsoft.com/en-us/azure/foundry/how-to/configure-private-link

## Prerequisites
- An Azure subscription with permissions to create resources and assign RBAC (`Owner` or `Role Based Access Control Administrator` + `Foundry Account Owner`).
- Registered resource providers: `Microsoft.Network`, `Microsoft.KeyVault`, `Microsoft.CognitiveServices`, `Microsoft.Storage`, `Microsoft.Search`, `Microsoft.ContainerService`.
- **Terraform >= 1.6**
- **Azure CLI >= 2.86.0** (required for the preview `az cognitiveservices account managed-network` commands).
- A supported managed virtual network region (for example `eastus2`, `swedencentral`, `uksouth`, `japaneast`, `westus3`, `australiaeast`).

## Cost Notice
- The Foundry managed virtual network feature itself is **free**.
- You are billed for **Azure Private Link** (managed private endpoints) and for **Azure Firewall** once an FQDN outbound rule is added in `AllowOnlyApprovedOutbound` mode (`Basic` or `Standard` SKU; SKU cannot be changed after deployment).
- Destroy the lab when finished to stop ongoing charges.

## 1. Configure Variables
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your subscription_id, region, and unique prefix
```

## 2. Deploy with Terraform
```bash
az login
terraform init
terraform plan -out tfplan
terraform apply tfplan
```

## 3. Verify with Azure CLI
Confirm the managed virtual network isolation mode:
```bash
az cognitiveservices account managed-network show \
  --resource-group <resource_group_name> \
  --name <foundry_account_name>
```

List all outbound rules (system-created + user-defined) and their status:
```bash
az cognitiveservices account managed-network outbound-rule list \
  --resource-group <resource_group_name> \
  --name <foundry_account_name>
```

(Optional) Add an FQDN outbound rule via Azure CLI (ports 80 and 443 only):
```bash
az cognitiveservices account managed-network outbound-rule set \
  --resource-group <resource_group_name> \
  --name <foundry_account_name> \
  --rule allow-openai-fqdn \
  --type fqdn \
  --destination "*.openai.azure.com"
```

## 4. Destroy & Clean Up
Deleting the Foundry resource also deletes its Microsoft-managed virtual network and managed firewall:
```bash
terraform destroy
```
Verify the resource group has been removed:
```bash
az group exists --name <resource_group_name>
```
