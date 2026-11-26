#!/usr/bin/env bash
set -euo pipefail

# Azure CLI helper walkthrough for the Front Door Premium WAF + Private Link lab.
# Run after `terraform apply` completes.

RG=$(terraform output -raw resource_group_name)
WEBAPP=$(terraform output -raw web_app_name)
FD_URL=$(terraform output -raw frontdoor_url)
ORIGIN_URL=$(terraform output -raw origin_direct_url)

echo "=== 1. List pending Private Endpoint connections on the Web App ==="
az network private-endpoint-connection list \
  --resource-group "$RG" \
  --name "$WEBAPP" \
  --type "Microsoft.Web/sites" \
  --output table

PE_ID=$(az network private-endpoint-connection list \
  --resource-group "$RG" \
  --name "$WEBAPP" \
  --type "Microsoft.Web/sites" \
  --query "[?properties.privateLinkServiceConnectionState.status=='Pending'].id | [0]" \
  --output tsv)

if [[ -n "${PE_ID:-}" ]]; then
  echo "=== 2. Approving pending Private Endpoint connection ==="
  az network private-endpoint-connection approve \
    --id "$PE_ID" \
    --description "Approved for Front Door Premium Private Link lab"
  echo "Wait 2-5 minutes for the Private Link connection to establish before testing."
else
  echo "No pending Private Endpoint connection found (already approved or still provisioning)."
fi

echo "=== 3. Test legitimate request through Front Door (expect HTTP 200) ==="
curl -i -sS "$FD_URL/" | head -n 15

echo "=== 4. Test custom WAF rule match (Detection: 200 + logged; Prevention: 403 Blocked) ==="
curl -i -sS -H "X-Lab-Test: block-me-lab" "$FD_URL/" | head -n 15

echo "=== 5. Test managed DRS rule match with safe synthetic SQLi query string ==="
curl -i -sS "$FD_URL/?q=%27%20or%201=1" | head -n 15

echo "=== 6. Prove direct public bypass to the origin is blocked (expect HTTP 403 Ip Forbidden) ==="
curl -i -sS "$ORIGIN_URL/" | head -n 15

echo "=== Done. To switch WAF to Prevention mode: terraform apply -var=\"waf_mode=Prevention\" ==="
echo "=== To tear down all lab resources so charges stop: terraform destroy ==="
