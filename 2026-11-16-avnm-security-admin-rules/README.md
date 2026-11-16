# Azure Virtual Network Manager security admin rules

Terraform practice lab for the Azure New Features video "Azure Virtual Network Manager Security Admin Rules: Central Guardrails Above NSGs" (YouTube playlist **azure new features**, Network Technician channel).

Security admin rules are global network security rules, defined centrally and evaluated **before** network security group rules. They can Allow, Deny or Always Allow traffic for every virtual network in a network group.

## What it builds

| Piece | Why it matters |
| --- | --- |
| Two VNets (`prod`, `dev`) and an application-team NSG that denies TCP 443 inbound | The lower-priority layer an app team controls |
| Virtual Network Manager, scope access `SecurityAdmin`, scoped to the subscription | The central governance object |
| Network group with two static members | Which VNets are governed |
| Security admin configuration, one rule collection | Only one security admin configuration can be deployed per region; use more collections instead |
| Rule 10 Always Allow, monitoring prefix to TCP 443 | Ends evaluation; the NSG deny cannot break monitoring |
| Rule 20 Allow, management prefix to TCP 22 | Exception that still lets NSGs decide |
| Rule 100 Deny, Internet service tag to high-risk ports | Cannot be overridden by NSGs |
| `azurerm_network_manager_deployment` | Rules do nothing until the configuration is deployed to a region |

## Prerequisites

Azure subscription and Azure CLI login, Terraform 1.6+, provider `hashicorp/azurerm` 5.14.0, permission to create Network Manager resources at subscription scope.

## Cost warning

Azure Virtual Network Manager is billed per subscription scope that is managed by the manager; the VNets, NSG and rules are free. Delete the lab when you finish.

## Steps

```bash
az login
export ARM_SUBSCRIPTION_ID="<your subscription id>"
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

Rules are eventually consistent and take a short time to appear. Look at the effective security admin rules on a network interface or at the VNet in the portal under Network Manager, then test with Network Watcher connection troubleshoot or IP flow verify.

## Experiments

1. Change rule 20 from `Allow` to `AlwaysAllow` and compare the evaluation result when an NSG denies port 22.
2. Change rule 10 to `Allow` and see the app-team NSG deny on 443 win again.
3. Add a third VNet to the network group and watch it pick up the rules.
4. Remove the deployment resource, apply, and confirm that deleting rules is not the same as un-deploying them.

Destroy with `terraform destroy`.
