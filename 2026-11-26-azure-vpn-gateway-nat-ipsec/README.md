# Azure VPN Gateway NAT and Custom IPsec/IKE Policy Lab

Practice lab for the Network Technician lesson on **Azure VPN Gateway NAT** (for overlapping RFC 1918 address spaces) and **Custom IPsec/IKE Connection Policies**, built with **Terraform** and **Azure CLI**.

> **COST AND TIMING WARNING:** An Azure VPN Gateway bills hourly from the moment it is provisioned until it is deleted, even if no traffic flows. Provisioning typically takes **30 to 45+ minutes**, and `terraform destroy` can also take **15 to 30+ minutes**. Destroy all resources as soon as you finish verifying the configuration.

## Official Microsoft Learn Sources

All architecture rules, SKU requirements, NAT rule behaviors, and cryptographic policy options in this lab follow these official Microsoft Learn pages:

- About NAT on Azure VPN Gateway: https://learn.microsoft.com/en-us/azure/vpn-gateway/nat-overview
- How to configure NAT for Azure VPN Gateway: https://learn.microsoft.com/en-us/azure/vpn-gateway/nat-howto
- Configure custom IPsec/IKE connection policies: https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-ipsecikepolicy-rm-powershell
- About cryptographic requirements and Azure VPN gateways: https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-compliance-crypto
- Azure CLI `az network vnet-gateway nat-rule`: https://learn.microsoft.com/en-us/cli/azure/network/vnet-gateway/nat-rule
- Azure CLI `az network vpn-connection ipsec-policy`: https://learn.microsoft.com/en-us/cli/azure/network/vpn-connection/ipsec-policy

## Chosen SKU and Official Justification

- **SKU:** `VpnGw2` (`RouteBased`, `Generation2`)
- **Why `VpnGw2`:** Official Microsoft Learn documentation states that **VPN Gateway NAT is supported only on `VpnGw2` through `VpnGw5` and `VpnGw2AZ` through `VpnGw5AZ`**. Although custom IPsec/IKE policies are supported starting on `VpnGw1` / `VpnGw1AZ`, `VpnGw1` does **not** support NAT. Therefore, `VpnGw2` is the lowest-cost officially valid SKU that supports both NAT and custom IPsec/IKE policy together.
- **Traffic selector constraint:** Official docs state that NAT rules are **not** supported on connections with `UsePolicyBasedTrafficSelectors` enabled or on Policy-Based VPN gateways. This lab keeps `use_policy_based_traffic_selectors = false` on a `RouteBased` gateway.

## Lab Topology

All three networks intentionally use the same overlapping `10.0.1.0/24` prefix (matching Microsoft Learn's official NAT example):

| Network | Original CIDR (Internal Mapping) | NAT Rule & Mode | Translated CIDR (External Mapping) |
| :--- | :--- | :--- | :--- |
| Azure VNet (`vnet-azure-hub`) | `10.0.1.0/24` | `nat-egress-vnet` (`EgressSnat`, `Static`) | `192.168.1.0/24` |
| Branch 1 (`lng-branch1`, simulated peer `198.51.100.10`) | `10.0.1.0/24` | `nat-ingress-branch1` (`IngressSnat`, `Static`) | `192.168.2.0/24` |
| Branch 2 (`lng-branch2`, simulated peer `203.0.113.10`) | `10.0.1.0/24` | `nat-ingress-branch2` (`IngressSnat`, `Static`) | `192.168.3.0/24` |

Per-connection custom IPsec/IKEv2 policies:
- **`conn-vnet-to-branch1`**: IKE `AES256` / `SHA384` / `DHGroup24`, IPsec `GCMAES256` / `GCMAES256` / `PFS24`, SA lifetime `14400`s / `102400000` KB, DPD `45`s.
- **`conn-vnet-to-branch2`**: IKE `AES256` / `SHA256` / `ECP384`, IPsec `AES256` / `SHA256` / `ECP384`, SA lifetime `27000`s / `102400000` KB, DPD `45`s.

> **Simulated Peers:** `lng-branch1` and `lng-branch2` default to RFC 5737 documentation IPs (`198.51.100.10` and `203.0.113.10`) so you can inspect the control-plane NAT rules, custom IPsec/IKE policies, and effective configuration without paying for a second gateway. If you have a real on-premises VPN device or a second disposable gateway, override `branch1_peer_ip` and `branch2_peer_ip` in `terraform.tfvars` and configure the exact matching IPsec/IKE policy on your peer.

## Deploy with Terraform

1. Authenticate to Azure:
   ```bash
   az login
   az account show
   ```
2. Copy the example variables file and set a strong pre-shared key:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
3. Initialize, review the plan, and apply:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Verify with Azure CLI

Run the inspection commands in `cli-lab.sh` (or individually):

```bash
# List NAT rules on the VPN Gateway
az network vnet-gateway nat-rule list \
  --resource-group rg-vpn-nat-ipsec-lab \
  --gateway-name vgw-azure-hub \
  --output table

# List custom IPsec/IKE policy on conn-vnet-to-branch1
az network vpn-connection ipsec-policy list \
  --resource-group rg-vpn-nat-ipsec-lab \
  --connection-name conn-vnet-to-branch1 \
  --output table

# Inspect NAT rule bindings, traffic selector mode, DPD timeout, and IPsec policy
az network vpn-connection show \
  --resource-group rg-vpn-nat-ipsec-lab \
  --name conn-vnet-to-branch1 \
  --query "{name:name, protocol:connectionProtocol, status:connectionStatus, policyBasedSelectors:usePolicyBasedTrafficSelectors, dpdTimeout:dpdTimeoutSeconds, ingressNat:ingressNatRules[].id, egressNat:egressNatRules[].id, ipsecPolicies:ipsecPolicies}" \
  --output json
```

## Destroy / Cleanup

To stop all hourly VPN Gateway charges immediately after your lab:

```bash
terraform destroy
```

Verify the resource group is gone:

```bash
az group exists --name rg-vpn-nat-ipsec-lab
```

If anything remains, force-remove the resource group:

```bash
az group delete --name rg-vpn-nat-ipsec-lab --yes --no-wait
```
