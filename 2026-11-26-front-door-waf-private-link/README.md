# Azure Front Door Premium WAF + Private Link Origin Practice Lab

This practice lab deploys **Azure Front Door Premium** with a **WAF Policy** (custom match rule + Microsoft Default Rule Set 2.1 + Bot Manager 1.1) in front of an **Azure App Service (Linux Web App)** whose public network access is disabled and reached exclusively over **Azure Private Link**. Diagnostic settings stream `FrontDoorWebApplicationFirewallLog`, `FrontDoorAccessLog`, and `FrontDoorHealthProbeLog` into a Log Analytics workspace.

## Official Microsoft Learn Sources
- [Azure Web Application Firewall on Azure Front Door](https://learn.microsoft.com/en-us/azure/web-application-firewall/afds/afds-overview)
- [Secure your origin with Private Link in Azure Front Door Premium](https://learn.microsoft.com/en-us/azure/frontdoor/private-link)
- [Front Door tier comparison](https://learn.microsoft.com/en-us/azure/frontdoor/standard-premium/tier-comparison)
- [Front Door WAF DRS rule groups and rules](https://learn.microsoft.com/en-us/azure/web-application-firewall/afds/waf-front-door-drs)
- [Azure WAF monitoring and logging](https://learn.microsoft.com/en-us/azure/web-application-firewall/afds/waf-front-door-monitor)
- [Connect Azure Front Door Premium to an App Service origin with Private Link](https://learn.microsoft.com/en-us/azure/frontdoor/standard-premium/how-to-enable-private-link-web-app)

## Prerequisites
- Azure subscription with permissions to create Front Door Premium, App Service, Log Analytics, and approve Private Endpoint connections.
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) signed in (`az login`) and active subscription selected (`az account set --subscription "<your-subscription>"`).
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6.0.

> **Cost Note:** Azure Front Door Premium and App Service `P0v3` incur hourly/monthly charges while deployed. Always run `terraform destroy` as soon as you finish the exercises.

## Step 1: Configure Variables
```bash
cp terraform.tfvars.example terraform.tfvars
```
Keep `waf_mode = "Detection"` for the initial deploy so you can observe Detection-mode logging before switching to `Prevention`.

> **Security Note:** Never commit `terraform.tfvars`, `.terraform/`, `*.tfstate`, or subscription IDs to source control.

## Step 2: Deploy with Terraform
```bash
terraform init
terraform plan
terraform apply
```

## Step 3: Approve the Private Endpoint Connection
Front Door Premium creates a managed private endpoint request in your App Service that starts in `Pending` state. Approve it using Azure CLI:

```bash
RG=$(terraform output -raw resource_group_name)
WEBAPP=$(terraform output -raw web_app_name)

# List pending private endpoint connections
az network private-endpoint-connection list \
  --resource-group "$RG" \
  --name "$WEBAPP" \
  --type "Microsoft.Web/sites" \
  --output table

# Approve the pending connection
PE_ID=$(az network private-endpoint-connection list \
  --resource-group "$RG" \
  --name "$WEBAPP" \
  --type "Microsoft.Web/sites" \
  --query "[?properties.privateLinkServiceConnectionState.status=='Pending'].id | [0]" \
  --output tsv)

az network private-endpoint-connection approve \
  --id "$PE_ID" \
  --description "Approved for Front Door Premium Private Link"
```
Wait 2 to 5 minutes for the Private Link connection to finish establishing.

## Step 4: Safe Allow, Block, and Public-Bypass Tests
```bash
FD_URL=$(terraform output -raw frontdoor_url)
ORIGIN_URL=$(terraform output -raw origin_direct_url)

# 1. Legitimate request through Front Door -> HTTP 200
curl -i "$FD_URL/"

# 2. Custom rule trigger (X-Lab-Test header)
#    In Detection mode: HTTP 200 (logged in WAF logs)
#    In Prevention mode: HTTP 403 ("Blocked by Azure Front Door WAF Lab Policy")
curl -i -H "X-Lab-Test: block-me-lab" "$FD_URL/"

# 3. Managed DRS SQLi signature trigger
curl -i "$FD_URL/?q=%27%20or%201=1"

# 4. Direct public bypass test to the App Service origin -> HTTP 403 (public access disabled)
curl -i "$ORIGIN_URL/"
```

### Switch from Detection Mode to Prevention Mode
After confirming matches appear in `FrontDoorWebApplicationFirewallLog`:
```bash
terraform apply -var="waf_mode=Prevention"
```
Re-run tests 2 and 3 and verify HTTP `403` responses with an `X-Azure-Ref` header.

## Step 5: Query WAF Logs in Log Analytics (KQL)
Wait ~5 minutes for Azure Monitor log ingestion, then run in your Log Analytics workspace:
```kql
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.CDN"
  and Category == "FrontDoorWebApplicationFirewallLog"
| project TimeGenerated, policyMode_s, action_s, ruleName_s,
          clientIP_s, requestUri_s, trackingReference_s
| order by TimeGenerated desc
```
Match `trackingReference_s` against the `X-Azure-Ref` response header returned by `curl -i`.

## Step 6: Teardown and Cleanup (Stop All Charges)
```bash
terraform destroy
```
Confirm all resources are deleted (deleting the Front Door profile also removes its managed Private Endpoint):
```bash
az group show --name "$(terraform output -raw resource_group_name 2>/dev/null || echo rg-afd-waf-pl-lab)"
```
If the resource group no longer exists, Azure CLI returns `ResourceGroupNotFound` and all lab billing has stopped.
