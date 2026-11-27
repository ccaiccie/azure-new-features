#!/usr/bin/env bash
# Companion Azure CLI walkthrough and operational verification script
# for Azure VPN Gateway NAT + Custom IPsec/IKE Policy.
#
# COST WARNING:
# An Azure VPN Gateway (VpnGw2) bills hourly until deleted and typically
# takes 30 to 45+ minutes to provision or destroy.
#
# Set your own shared key before running:
#   export VPN_SHARED_KEY="YourStrongLabSharedKey!"

set -euo pipefail

RG="rg-vpn-nat-ipsec-lab"
LOC="eastus"
VNET="vnet-azure-hub"
VGW="vgw-azure-hub"
PIP="pip-vgw-azure-hub"
SHARED_KEY="${VPN_SHARED_KEY:-REPLACE-WITH-STRONG-LAB-PSK}"

# ------------------------------------------------------------------------------
# 1. Create NAT rules via Azure CLI (if building with CLI instead of Terraform)
#    Note: az network vnet-gateway nat-rule is marked Preview in Azure CLI docs.
# ------------------------------------------------------------------------------
# az network vnet-gateway nat-rule add \
#   --resource-group "$RG" \
#   --gateway-name "$VGW" \
#   --name nat-egress-vnet \
#   --mode EgressSnat \
#   --type Static \
#   --internal-mappings 10.0.1.0/24 \
#   --external-mappings 192.168.1.0/24
#
# az network vnet-gateway nat-rule add \
#   --resource-group "$RG" \
#   --gateway-name "$VGW" \
#   --name nat-ingress-branch1 \
#   --mode IngressSnat \
#   --type Static \
#   --internal-mappings 10.0.1.0/24 \
#   --external-mappings 192.168.2.0/24

# ------------------------------------------------------------------------------
# 2. Apply or update a Custom IPsec/IKE Policy on an existing connection
# ------------------------------------------------------------------------------
# az network vpn-connection ipsec-policy add \
#   --resource-group "$RG" \
#   --connection-name conn-vnet-to-branch1 \
#   --ike-encryption AES256 \
#   --ike-integrity SHA384 \
#   --dh-group DHGroup24 \
#   --ipsec-encryption GCMAES256 \
#   --ipsec-integrity GCMAES256 \
#   --pfs-group PFS24 \
#   --sa-lifetime 14400 \
#   --sa-max-size 102400000

# ------------------------------------------------------------------------------
# 3. Operational Verification: inspect NAT rules, custom IPsec/IKE policies,
#    and effective connection configuration
# ------------------------------------------------------------------------------
echo "=== 1. List NAT rules on the VPN Gateway ==="
az network vnet-gateway nat-rule list \
  --resource-group "$RG" \
  --gateway-name "$VGW" \
  --output table

echo "=== 2. Inspect Custom IPsec/IKE Policy on conn-vnet-to-branch1 ==="
az network vpn-connection ipsec-policy list \
  --resource-group "$RG" \
  --connection-name conn-vnet-to-branch1 \
  --output table

echo "=== 3. Inspect NAT bindings, traffic selector flags, and DPD timeout ==="
az network vpn-connection show \
  --resource-group "$RG" \
  --name conn-vnet-to-branch1 \
  --query "{name:name, protocol:connectionProtocol, status:connectionStatus, policyBasedSelectors:usePolicyBasedTrafficSelectors, dpdTimeout:dpdTimeoutSeconds, ingressNat:ingressNatRules[].id, egressNat:egressNatRules[].id, ipsecPolicies:ipsecPolicies}" \
  --output json

echo "=== 4. Inspect conn-vnet-to-branch2 ==="
az network vpn-connection show \
  --resource-group "$RG" \
  --name conn-vnet-to-branch2 \
  --query "{name:name, protocol:connectionProtocol, status:connectionStatus, policyBasedSelectors:usePolicyBasedTrafficSelectors, dpdTimeout:dpdTimeoutSeconds, ingressNat:ingressNatRules[].id, egressNat:egressNatRules[].id, ipsecPolicies:ipsecPolicies}" \
  --output json

# ------------------------------------------------------------------------------
# 4. Cleanup / Destroy (uncomment to delete the entire resource group via CLI)
# ------------------------------------------------------------------------------
# az group delete --name "$RG" --yes --no-wait
