#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./verify-and-destroy.sh verify <apim-name> [resource-group]
#   ./verify-and-destroy.sh destroy [resource-group]

ACTION="${1:-verify}"
APIM_NAME="${2:-}"
RG="${3:-rg-apim-net-v2}"

if [[ "$ACTION" == "verify" ]]; then
  if [[ -z "$APIM_NAME" ]]; then
    echo "Usage: $0 verify <apim-name> [resource-group]"
    exit 1
  fi

  echo "=== 1. Check APIM Internal VNet Mode & Private VIP ==="
  az apim show \
    --resource-group "$RG" \
    --name "$APIM_NAME" \
    --query "{name:name, sku:sku.name, vnetType:virtualNetworkType, privateIPs:privateIpAddresses}" \
    -o table

  echo "=== 2. Check Scoped Private DNS Zone Record ==="
  az network private-dns record-set a show \
    --resource-group "$RG" \
    --zone-name "${APIM_NAME}.azure-api.net" \
    --name "@" \
    --query "{fqdn:fqdn, records:aRecords[].ipv4Address}" \
    -o table

  echo "=== 3. Check Application Gateway WAF_v2 Backend Health ==="
  az network application-gateway show-backend-health \
    --resource-group "$RG" \
    --name "agw-apim-v2" \
    --query "backendAddressPools[].backendHttpSettingsCollection[].servers[].{address:address,health:health}" \
    -o table

  echo "=== 4. Test App Gateway Public Path (Status Probe) ==="
  APPGW_IP=$(az network public-ip show -g "$RG" -n "pip-agw-apim-v2" --query ipAddress -o tsv)
  echo "Testing http://${APPGW_IP}/status-0123456789abcdef ..."
  curl -i -s "http://${APPGW_IP}/status-0123456789abcdef" | head -n 5

elif [[ "$ACTION" == "destroy" ]]; then
  RG="${2:-rg-apim-net-v2}"
  echo "=== Destroying Terraform Lab Resources ==="
  terraform destroy -auto-approve
  echo "=== Verifying Resource Group Deletion ==="
  if [[ "$(az group exists --name "$RG")" == "true" ]]; then
    echo "Resource group $RG still exists; deleting via Azure CLI..."
    az group delete --name "$RG" --yes --no-wait
  else
    echo "Confirmed: resource group $RG is deleted."
  fi
else
  echo "Unknown action: $ACTION (use 'verify' or 'destroy')"
  exit 1
fi
