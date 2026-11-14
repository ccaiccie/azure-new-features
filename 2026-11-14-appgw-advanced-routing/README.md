# Application Gateway path-based routing (advanced routing lesson)

Terraform practice lab for this video: https://youtu.be/OYnmmPclLog

## Goals

- Deploy Application Gateway Standard_v2 with autoscaling
- Configure a path-based routing rule that sends `/api/*` and `/app/*` to different backend pools, with a default pool
- Attach a rewrite rule set that runs after the routing decision, as the lesson describes in the decision flow

## Prerequisites

- An Azure subscription and the `az` CLI (`az login`) plus `terraform` 1.6+
- A contributor role on the subscription or a resource group where you can create the lab resources

## Cost warning

Application Gateway Standard_v2 is billed for capacity units and for the time the gateway exists. This lab sets `min_capacity = 0` so it can scale to zero when idle, but creating the gateway and a Standard public IP still incurs charges. There are no virtual machines and no WAF. Destroy the resource group as soon as you finish.

## What this lab cannot provision

Advanced routing rules, advanced routing maps, condition sets (path, header, query string, HTTP method, client IP), pool selection by weight or by priority with Minimum Healthy Percent, and server selection by weighted round robin or least connections are public preview and are configured with API version 2026-03-01 or later and the `az network application-gateway advanced-routing-map` CLI. azurerm 5.14.0's `azurerm_application_gateway` does not document those arguments. This lab does not invent them.

The nearest generally available configuration is a path-based `url_path_map` plus a rewrite rule set. After apply, you can try the preview commands from the lesson against this gateway if your subscription has preview access.

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

## Verify

```bash
terraform output
az network application-gateway show --resource-group rg-appgw-routing-lab --name appgwlab-appgw --query '{sku:sku,rules:requestRoutingRules[].name,maps:urlPathMaps[].name}'
az network application-gateway url-path-map show --resource-group rg-appgw-routing-lab --gateway-name appgwlab-appgw --name path-map
curl -sI "http://$(terraform output -raw public_ip)/api/health" || true
```

Expect the path map to list the `api` and `app` path rules. A request to `www.example.com` may not return the lab header if that public site is not a real backend you control; the configuration is still present on the gateway.

## Cleanup

Destroy the lab when you are finished so you are not billed for idle resources:

```bash
terraform destroy
```

Confirm in the Azure portal that the resource group is gone.
