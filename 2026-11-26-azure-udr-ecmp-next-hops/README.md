# Azure Virtual Network ECMP Next Hops for UDRs — Practice Lab (Public Preview)

> **Public Preview Notice:** Equal-Cost Multi-Path (ECMP) routing for Azure Virtual Network user-defined routes (`VirtualApplianceEcmp`) is in **public preview** (announced November 25, 2026, Azure Updates ID 582326). Do not rely on preview behavior for production SLA workloads without reviewing Microsoft's preview terms.

## What This Lab Builds

A small **hub-and-spoke** Virtual Network lab that demonstrates a single UDR distributing traffic across multiple Network Virtual Appliances (NVAs):

- **Hub VNet (`vnet-hub`, `10.10.0.0/16`)**
  - Dedicated NVA subnet (`snet-nva`, `10.10.1.0/24`) — separated from source workloads to avoid routing loops.
  - 2 Linux NVA VMs (`vm-nva-1` at `10.10.1.4`, `vm-nva-2` at `10.10.1.5`) with IP forwarding enabled on **both** each Azure NIC (`ip_forwarding_enabled = true`) and inside the guest OS (`net.ipv4.ip_forward = 1`).
- **Spoke A VNet (`vnet-spoke-a`, `10.20.0.0/16`)**
  - Source workload subnet (`snet-workload`, `10.20.1.0/24`) with `vm-src-spoke-a` (`10.20.1.4`).
  - Associated with `rt-spoke-a-ecmp`, containing `to-spoke-b-ecmp` (`10.30.1.0/24` -> `VirtualApplianceEcmp` -> `["10.10.1.4", "10.10.1.5"]`).
- **Spoke B VNet (`vnet-spoke-b`, `10.30.0.0/16`)**
  - Destination subnet (`snet-dest`, `10.30.1.0/24`) with `vm-dest-spoke-b` (`10.30.1.4`).
  - Associated with `rt-spoke-b-ecmp` for the return prefix (`10.20.1.0/24`).

## Prerequisites

1. **Register the preview feature** in your subscription (requires `Microsoft.Features/*` and `Microsoft.Network` permissions):

   ```bash
   az account set --subscription "<your-subscription-id>"
   az feature register --namespace Microsoft.Network --name AllowEcmpInRoute
   az feature show --namespace Microsoft.Network --name AllowEcmpInRoute --query properties.state --output tsv
   ```

   Wait until the state changes from `Registering` or `Pending` to `Registered`, then re-register the resource provider:

   ```bash
   az provider register --namespace Microsoft.Network
   az provider show --namespace Microsoft.Network --query registrationState --output tsv
   ```

2. **Tooling version caution:** Use a current version of Azure CLI (or `Az.Network` PowerShell) that supports `VirtualApplianceEcmp` and `--next-hop`. Older minimum versions listed in earlier tutorials may not support ECMP.
3. **Limit note:** Official Azure Updates (582326), the Virtual Network routing overview, and the route table tutorial state **2 to 16** next-hop IP addresses per route. (The ARM/Bicep/AzAPI template reference currently lists 2 to 64; follow the official overview and Azure Updates limit of 2 to 16.)

## Deploy with Terraform

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your subscription_id and ssh_public_key_path
# Never commit terraform.tfvars or *.tfstate files

terraform init
terraform plan
terraform apply
```

## Update or Inspect with Azure CLI

See [`ecmp-cli.sh`](./ecmp-cli.sh) for the full Azure CLI workflow. To update an existing route to ECMP:

```bash
az network route-table route create \
  --resource-group rg-udr-ecmp-lab \
  --route-table-name rt-spoke-a-ecmp \
  --name to-spoke-b-ecmp \
  --address-prefix 10.30.1.0/24 \
  --next-hop-type VirtualApplianceEcmp \
  --next-hop "next-hop-ip-addresses=[10.10.1.4,10.10.1.5]"
```

Inspect the saved route:

```bash
az network route-table route show \
  --resource-group rg-udr-ecmp-lab \
  --route-table-name rt-spoke-a-ecmp \
  --name to-spoke-b-ecmp \
  --query "{addressPrefix:addressPrefix,nextHopType:nextHopType,nextHop:nextHop,provisioningState:provisioningState}" \
  --output json
```

## Verify Multi-NVA Traffic Distribution (Official Method)

Per the official Microsoft Learn tutorial:

1. Check **effective routes** on `nic-src-spoke-a`:
   ```bash
   az network nic show-effective-route-table \
     --resource-group rg-udr-ecmp-lab \
     --name nic-src-spoke-a \
     --output table
   ```
2. Remember: a `ProvisioningState` of `Succeeded` only confirms Azure provisioned the route resource — it does **not** verify NVA health, equal traffic distribution, session-state synchronization, or failover.
3. Start a lightweight HTTP listener on `vm-dest-spoke-b` (e.g., `python3 -m http.server 8080`) and run packet captures (`sudo tcpdump -ni any host 10.30.1.4 and tcp port 8080`) or check forwarding counters on **both** `vm-nva-1` and `vm-nva-2`.
4. From `vm-src-spoke-a`, open **multiple independent connections** (for example, a loop of `curl -s http://10.30.1.4:8080/ > /dev/null` across distinct source ports). A single `tracepath` result does **not** show traffic distribution across both NVAs.
5. Confirm packets appear across both `vm-nva-1` and `vm-nva-2`, and remember that ECMP does not guarantee return-path symmetry or session-state sync for stateful firewalls.

## Teardown / Cleanup (Stop All Charges)

```bash
terraform destroy
```

Or with Azure CLI:

```bash
az group delete --name rg-udr-ecmp-lab --yes --no-wait
```

> **Note:** Deleting the resource group removes all VMs, NICs, VNets, and route tables so charges stop, but it does **not** unregister the subscription-level `Microsoft.Network/AllowEcmpInRoute` feature.

## Official Sources

- Azure Updates / Message Center AZ582326 (Public Preview, November 25, 2026): https://mc.merill.net/message/AZ582326
- Azure virtual network traffic routing (UDR overview & `VirtualApplianceEcmp` public preview): https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-udr-overview
- Tutorial: Route network traffic with a route table (Configure ECMP routing): https://learn.microsoft.com/en-us/azure/virtual-network/tutorial-create-route-table
- Azure CLI `az network route-table route` reference: https://learn.microsoft.com/en-us/cli/azure/network/route-table/route
- ARM / Bicep / Terraform AzAPI `Microsoft.Network/routeTables/routes` reference: https://learn.microsoft.com/en-us/azure/templates/microsoft.network/routetables/routes
