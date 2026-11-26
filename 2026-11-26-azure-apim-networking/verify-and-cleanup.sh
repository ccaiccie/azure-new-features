#!/usr/bin/env bash
# Verification and cleanup commands for the Azure API Management Networking Lab.
# Set these variables to match your terraform.tfvars values before running.

RG="rg-apim-networking-lab"
APIM_NAME="apim-ntlab-replace-me"
APPGW_NAME="agw-apim-lab"

echo "=== 1. Check API Management VNet mode and private IP ==="
az apim show \
  --resource-group "$RG" \
  --name "$APIM_NAME" \
  --query "{name:name, sku:sku.name, vnetType:virtualNetworkType, privateIps:privateIpAddresses, gatewayUrl:gatewayUrl}" \
  --output table

echo "=== 2. Check Application Gateway backend health ==="
az network application-gateway show-backend-health \
  --resource-group "$RG" \
  --name "$APPGW_NAME" \
  --output json

echo "=== 3. Verify scoped Private DNS record ==="
az network private-dns record-set a show \
  --resource-group "$RG" \
  --zone-name "${APIM_NAME}.azure-api.net" \
  --name "@" \
  --output table

echo "=== 4. Test gateway status endpoint through Application Gateway ==="
APPGW_IP=$(az network public-ip show --resource-group "$RG" --name "pip-appgw-apim-lab" --query ipAddress -o tsv)
curl -i "http://${APPGW_IP}/status-0123456789abcdef"

# ---------------------------------------------------------------------------
# Optional Reference: Disabling Public Network Access on Inbound Private Link
# (Only after an inbound Private Endpoint is configured on a supported tier;
#  NOT used on classic internal VNet-injected instances.)
# ---------------------------------------------------------------------------
# az apim update \
#   --name my-apim-service \
#   --resource-group my-resource-group \
#   --public-network-access false

# ---------------------------------------------------------------------------
# Teardown: Destroy all resources to stop billing!
# ---------------------------------------------------------------------------
# terraform destroy
# Verify the resource group is removed:
# az group show --name "$RG"
