#!/usr/bin/env bash
# ==============================================================================
# Azure CLI Companion Script — ECMP Next Hops for VNet UDRs (Public Preview)
# Use a current Azure CLI version that supports VirtualApplianceEcmp and --next-hop.
# ==============================================================================
set -euo pipefail

SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-<your-subscription-id>}"
RG_NAME="${RG_NAME:-rg-udr-ecmp-lab}"
RT_NAME="${RT_NAME:-rt-spoke-a-ecmp}"
ROUTE_NAME="${ROUTE_NAME:-to-spoke-b-ecmp}"
DEST_PREFIX="${DEST_PREFIX:-10.30.1.0/24}"
NVA_IPS="${NVA_IPS:-[10.10.1.4,10.10.1.5]}"

echo "==> Step 1: Select subscription and register Microsoft.Network/AllowEcmpInRoute"
az account set --subscription "$SUBSCRIPTION_ID"
az feature register --namespace Microsoft.Network --name AllowEcmpInRoute

echo "==> Step 2: Check feature registration state (wait until Registered)"
az feature show \
  --namespace Microsoft.Network \
  --name AllowEcmpInRoute \
  --query properties.state \
  --output tsv

echo "==> Step 3: Re-register Microsoft.Network after feature state is Registered"
az provider register --namespace Microsoft.Network
az provider show --namespace Microsoft.Network --query registrationState --output tsv

echo "==> Step 4: Create or update the UDR with VirtualApplianceEcmp (2 to 16 next hops)"
az network route-table route create \
  --resource-group "$RG_NAME" \
  --route-table-name "$RT_NAME" \
  --name "$ROUTE_NAME" \
  --address-prefix "$DEST_PREFIX" \
  --next-hop-type VirtualApplianceEcmp \
  --next-hop "next-hop-ip-addresses=${NVA_IPS}"

echo "==> Step 5: Verify saved route configuration"
az network route-table route show \
  --resource-group "$RG_NAME" \
  --route-table-name "$RT_NAME" \
  --name "$ROUTE_NAME" \
  --query "{addressPrefix:addressPrefix,nextHopType:nextHopType,nextHop:nextHop,provisioningState:provisioningState}" \
  --output json

echo "==> Step 6: Inspect effective routes on the Spoke A source VM NIC"
az network nic show-effective-route-table \
  --resource-group "$RG_NAME" \
  --name nic-src-spoke-a \
  --output table

# Cleanup (run manually when finished so charges stop):
# az group delete --name "$RG_NAME" --yes --no-wait
# Note: Deleting the resource group does not unregister AllowEcmpInRoute.
