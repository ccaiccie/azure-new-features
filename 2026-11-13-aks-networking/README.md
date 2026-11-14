# AKS networking: Cilium, ACNS, and Fleet Manager

Terraform practice lab for this video: https://youtu.be/vS350HXXmzw

## Goals

- Create an Azure Kubernetes Fleet Manager
- Optionally create a one-node AKS cluster with Azure CNI Overlay, the Cilium data plane, and Advanced Container Networking Services (`advanced_networking.observability_enabled` and `security_enabled`)
- Join that cluster to the fleet as a member

## Prerequisites

- An Azure subscription and the `az` CLI (`az login`) plus `terraform` 1.6+
- A contributor role on the subscription or a resource group where you can create the lab resources

- Permission to create AKS clusters and a Fleet Manager

## Cost warning

A running AKS cluster is billed for the system node VM, the control plane (Free tier has no Uptime SLA charge), and outbound data. Advanced Container Networking Services observability can add extra telemetry cost; the lesson discusses scoping that cost. This lab uses a single `Standard_D2s_v3` node. Destroy the cluster as soon as you finish. Set `create_cluster = false` to create only the fleet manager.

## What this lab cannot provision

The lesson covers four November 2026 items. This lab can provision Fleet Manager, a fleet member, Cilium, and ACNS observability/security flags.

It cannot provision:
- Cross-cluster networking for Azure Kubernetes Fleet Manager (the Cilium-based service connectivity the lesson describes). `azurerm_kubernetes_fleet_manager` in 5.14.0 does not expose a cross-cluster networking argument.
- Multi-NIC pods for AKS (public preview). There is no documented azurerm argument for a secondary pod NIC or DRAnet injection on the cluster or node pool.
- Managed DRANET for RDMA. There is no documented node-pool argument for managed DRANET or RDMA resource claims.
- Configurable ACNS observability dimensions (workload, namespace, Cilium identity). The provider exposes `observability_enabled`, not those dimension settings.

A second cluster would be required to actually try cross-cluster connectivity, which this lab omits to keep cost down.

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

Get credentials after apply:

```bash
az aks get-credentials --resource-group rg-aks-networking-lab --name aksnetlab-aks
```

## Verify

```bash
terraform output
az aks show --resource-group rg-aks-networking-lab --name aksnetlab-aks --query networkProfile
az kubernetesfleet list --resource-group rg-aks-networking-lab -o table
```

Confirm `networkDataplane` and `networkPolicy` are `cilium`, and that advanced networking observability and security are enabled.

## Cleanup

Destroy the lab when you are finished so you are not billed for idle resources:

```bash
terraform destroy
```

Confirm in the Azure portal that the resource group is gone.
