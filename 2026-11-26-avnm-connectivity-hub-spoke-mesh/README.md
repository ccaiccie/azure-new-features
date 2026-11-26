# Azure Virtual Network Manager Connectivity Lab: Hub-and-Spoke vs. Mesh

Hands-on Terraform and Azure CLI practice lab accompanying the Network Technician YouTube lesson on **Azure Virtual Network Manager (AVNM) Connectivity Configurations**.

- Intended public repository path: `ccaiccie/azure-new-features/2026-11-26-avnm-connectivity-hub-spoke-mesh`
- Courses: https://learn.techtohire.com
- Daily Quiz: https://quiz.techtohire.com
- Help & Consulting: https://www.techtohire.com/about

## Official Microsoft Learn Sources
- Connectivity configurations in Azure Virtual Network Manager: https://learn.microsoft.com/en-us/azure/virtual-network-manager/concept-connectivity-configuration
- What is Azure Virtual Network Manager?: https://learn.microsoft.com/en-us/azure/virtual-network-manager/overview
- What is a network group in Azure Virtual Network Manager?: https://learn.microsoft.com/en-us/azure/virtual-network-manager/concept-network-groups
- Manage configuration deployments in Azure Virtual Network Manager: https://learn.microsoft.com/en-us/azure/virtual-network-manager/concept-deployments
- Limitations with Azure Virtual Network Manager: https://learn.microsoft.com/en-us/azure/virtual-network-manager/concept-limitations
- Quickstart: Create a mesh network topology with Azure CLI: https://learn.microsoft.com/en-us/azure/virtual-network-manager/create-virtual-network-manager-cli
- Quickstart: Create a mesh network topology with Terraform: https://learn.microsoft.com/en-us/azure/virtual-network-manager/create-virtual-network-manager-terraform

## What This Lab Builds
- 1 Resource Group in `westus2` (configurable)
- 3 Virtual Networks with non-overlapping address spaces:
  - `vnet-hub-*` (`10.0.0.0/16`, subnet `10.0.0.0/24`)
  - `vnet-spoke-a-*` (`10.1.0.0/16`, subnet `10.1.0.0/24`)
  - `vnet-spoke-b-*` (`10.2.0.0/16`, subnet `10.2.0.0/24`)
- 1 Azure Virtual Network Manager instance (`Connectivity` scope access, scoped to your current subscription via `data.azurerm_subscription.current`)
- 1 Network Group (`ng-spokes`) with static members (`vnet-spoke-a`, `vnet-spoke-b`)
- Switchable Connectivity Configuration (`mesh` or `hub_and_spoke` with optional `enable_direct_connectivity`)
- Toggleable Deployment (`deploy_connectivity = false` for the BEFORE test, `true` for the AFTER test)
- 3 optional lightweight Ubuntu test VMs (`Standard_B1s`, no public IP addresses) so you can run ping checks safely via `az vm run-command invoke`

## Prerequisites
- Your own Azure subscription (never commit subscription IDs or secrets)
- Azure CLI (`az login` and `az account set --subscription "<your-subscription-id>"`)
- Azure Virtual Network Manager CLI extension: `az extension add -n virtual-network-manager`
- Terraform 1.5+

## Step-by-Step Terraform Walkthrough

### 1. Initialize and Configure Variables
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars and add your SSH public key
terraform init
```

### 2. Phase 1 (BEFORE): Deploy VNets & VMs Without Committing Connectivity
With `deploy_connectivity = false` in `terraform.tfvars`:
```bash
terraform apply
```
Record the resource group name and test VM private IPs from `terraform output`.

Test spoke-to-spoke reachability BEFORE deploying connectivity (expected: 100% packet loss):
```bash
RG=$(terraform output -raw resource_group_name)
SPOKE_B_IP=$(terraform output -json test_vm_private_ips | jq -r '.spoke_b')

az vm run-command invoke \
  -g "$RG" -n vm-spoke-a \
  --command-id RunShellScript \
  --scripts "ping -c 3 -W 2 $SPOKE_B_IP"
```

### 3. Phase 2 (AFTER — Mesh): Commit Mesh Connectivity
Set `topology_mode = "mesh"` and `deploy_connectivity = true` in `terraform.tfvars`, then apply:
```bash
terraform apply
```
Wait 1–2 minutes for AVNM to apply the goal state, then verify effective connectivity and ping again:
```bash
SPOKE_A_VNET=$(terraform output -json virtual_network_names | jq -r '.spoke_a')
az network manager list-effective-connectivity-config -g "$RG" --virtual-network-name "$SPOKE_A_VNET"
az network nic show-effective-route-table -g "$RG" -n nic-spoke_a -o table

az vm run-command invoke \
  -g "$RG" -n vm-spoke-a \
  --command-id RunShellScript \
  --scripts "ping -c 3 -W 2 $SPOKE_B_IP"
```
You should observe `0% packet loss` and a next hop type of `ConnectedGroup` in the effective route table.

### 4. Phase 3 (Compare Hub-and-Spoke)
Switch `terraform.tfvars` to:
```hcl
topology_mode              = "hub_and_spoke"
enable_direct_connectivity = false
deploy_connectivity        = true
```
Run `terraform apply`. Now `vm-spoke-a` reaches `vm-hub` via `VNetPeering`, while `vm-spoke-a` to `vm-spoke-b` is blocked. Flip `enable_direct_connectivity = true` and apply again to add a `ConnectedGroup` direct mesh between the spokes on top of hub-and-spoke.

### 5. Phase 4 (Clean Up & Stop Charges)
Always tear down the lab when finished so Azure charges stop:
```bash
# Step A: Remove the AVNM deployment first (clean goal-state removal)
terraform apply -var="deploy_connectivity=false"

# Step B: Destroy all lab resources
terraform destroy
```
If you used the Azure CLI walkthrough (`cli-walkthrough.sh`) instead, delete the entire resource group:
```bash
az group delete --name rg-avnm-cli-lab --yes --no-wait
```
