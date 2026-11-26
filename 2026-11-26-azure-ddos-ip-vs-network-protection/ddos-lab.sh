#!/usr/bin/env bash
# Azure CLI walkthrough for Azure DDoS IP Protection vs. DDoS Network Protection
# Peacetime configuration and validation only. Do NOT run attack simulations or traffic generators.
#
# COST WARNING:
# - Enabling DDoS IP Protection bills per protected public IP while active.
# - Creating a DDoS Network Protection plan bills until the plan resource is DELETED
#   (disabling on a virtual network alone does NOT stop plan billing).

set -euo pipefail

RG="rg-ddos-sku-lab"
LOC="eastus"
PIP="pip-ddos-ip-lab"
VNET="vnet-ddos-sku-lab"
PLAN="ddos-plan-sku-lab"

echo "=== 1. Create resource group ==="
az group create --name "$RG" --location "$LOC"

echo "=== 2. Create Standard SKU Public IP with DDoS IP Protection enabled ==="
az network public-ip create \
  --resource-group "$RG" \
  --name "$PIP" \
  --location "$LOC" \
  --allocation-method Static \
  --sku Standard \
  --ddos-protection-mode Enabled

echo "=== 3. Validate DDoS IP Protection status (ddosSettings.protectionMode == Enabled) ==="
az network public-ip show \
  --resource-group "$RG" \
  --name "$PIP" \
  --query "{name:name, sku:sku.name, ipAddress:ipAddress, ddosSettings:ddosSettings}"

echo "=== 4. Optional: Enable/Disable IP Protection on an existing Standard Public IP ==="
# az network public-ip update --resource-group "$RG" --name "$PIP" --ddos-protection-mode Enabled
# az network public-ip update --resource-group "$RG" --name "$PIP" --ddos-protection-mode Disabled

echo "=== 5. OPTIONAL (COMMENTED OUT - HIGH COST): Network Protection Plan on a VNet ==="
# COST WARNING: Uncomment only if you intend to pay for a DDoS Network Protection plan.
# az network ddos-protection create --resource-group "$RG" --name "$PLAN"
# az network vnet create --resource-group "$RG" --name "$VNET" --location "$LOC" \
#   --ddos-protection-plan "$PLAN" --ddos-protection true
# az network ddos-protection show --resource-group "$RG" --name "$PLAN"
#
# To disable on a VNet (does NOT stop plan billing!):
# az network vnet update --resource-group "$RG" --name "$VNET" \
#   --ddos-protection-plan "$PLAN" --ddos-protection false
#
# To delete the plan after dissociating all VNets:
# az network ddos-protection delete --resource-group "$RG" --name "$PLAN"

echo "=== 6. Cleanup (remove all lab resources to stop billing) ==="
echo "Run: az group delete --name $RG --yes --no-wait"
