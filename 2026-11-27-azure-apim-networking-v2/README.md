# Azure API Management Networking (v2 Purpose-First Lab)

Hands-on Terraform and Azure CLI practice lab demonstrating **Azure API Management in Internal VNet mode** fronted by **Azure Application Gateway (`WAF_v2`)** with **properly scoped Private DNS** and a private backend subnet.

> **COST & PROVISIONING WARNING:**
> - **Continuous billing:** Both Azure API Management (`Developer_1`) and Azure Application Gateway (`WAF_v2`) bill continuously from the moment they are provisioned until they are deleted — even with zero API traffic.
> - **SKU rationale:** This lab uses **`Developer_1`** because it is the **lowest-cost officially supported SKU** for classic internal VNet injection (Production requires `Premium` or `Premium v2`, which are significantly more expensive; check the current official [Azure API Management pricing page](https://azure.microsoft.com/pricing/details/api-management/) before deploying). Application Gateway uses `WAF_v2` with capacity `1` for non-production lab testing (Microsoft recommends a minimum of `2` instances for production).
> - **Provisioning time:** Expect **30 to 40 minutes** to create and activate a Developer-tier APIM instance in an internal VNet, plus ~10–15 minutes for Application Gateway.
> - **Always destroy the lab** immediately after verifying the paths (`terraform destroy`).

## Architecture & Why Each Piece Exists

1. **Virtual Network (`10.20.0.0/16`) with 3 Subnets**:
   - `snet-appgw` (`10.20.0.0/24`): Hosts Application Gateway `WAF_v2` for controlled external/partner entry.
   - `snet-apim` (`10.20.1.0/24`, **no subnet delegation**): Hosts internal-mode APIM so the gateway disappears from public DNS while reaching private backends.
   - `snet-backend` (`10.20.2.0/24`): Hosts private backend workloads (no public IPs) and an optional jump VM for internal testing.
2. **Minimum Official NSG Rules (`nsg-apim`)**:
   - Inbound `ApiManagement` -> `VirtualNetwork` TCP `3443` (control plane)
   - Inbound `AzureLoadBalancer` -> `VirtualNetwork` TCP `6390` (Azure Infrastructure LB)
   - Inbound `snet-appgw` (`10.20.0.0/24`) -> `snet-apim` (`10.20.1.0/24`) TCP `443`
   - Outbound `Storage` (443), `SQL` (1433), `AzureKeyVault` (443), `AzureMonitor` (1886, 443), `Internet` (80 for certificate validation)
3. **Internal-Mode APIM (May 2024 Public IP Update)**:
   - Official documentation conflict note: Microsoft's [Application Gateway integration guide](https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-integrate-internal-vnet-appgateway) still shows creating a Public IP for internal-mode APIM in its older PowerShell sample, whereas the authoritative [Internal VNet deployment guide](https://learn.microsoft.com/en-us/azure/api-management/api-management-using-with-internal-vnet) states that **starting May 2024, a customer-managed Public IP is no longer required for internal VNet injection**. This lab follows the current internal-VNet guidance and omits the extra Public IP.
4. **Scoped Private DNS Zone (NEVER Apex `azure-api.net`)**:
   - Creates a Private DNS zone scoped strictly to `<apim-name>.azure-api.net` with an `@` A record pointing to APIM's private virtual IP. Never create a Private DNS zone for the apex `azure-api.net` domain, as doing so breaks resolution for other Azure services.
5. **Application Gateway (`WAF_v2`) Custom Health Probe**:
   - Uses a custom HTTPS probe targeting `/status-0123456789abcdef` with the APIM gateway hostname in the `Host` header (default IP-based probes fail because APIM requires a valid Host header).

## Prerequisites

- Azure subscription with Contributor / Network Contributor permissions
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) logged in (`az login`)

## Deploy

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with a globally unique apim_name and your publisher_email

terraform init
terraform plan
terraform apply
```

> Wait ~30–40 minutes for `azurerm_api_management.this` to finish internal VNet activation.

## Verify (Azure CLI & Jump VM)

```bash
# 1. Confirm APIM is in Internal mode and inspect its private VIP
az apim show \
  --resource-group rg-apim-net-v2 \
  --name <your-apim-name> \
  --query "{name:name, sku:sku.name, vnetType:virtualNetworkType, privateIPs:privateIpAddresses}"

# 2. Confirm Application Gateway backend health is Healthy
az network application-gateway show-backend-health \
  --resource-group rg-apim-net-v2 \
  --name agw-apim-v2 \
  --query "backendAddressPools[].backendHttpSettingsCollection[].servers[].{address:address,health:health}"

# 3. From a VM inside the VNet (e.g., snet-backend), verify scoped Private DNS and gateway status
nslookup <your-apim-name>.azure-api.net
curl -i https://<your-apim-name>.azure-api.net/status-0123456789abcdef
# Expected: HTTP/1.1 200 Service Operational
```

See [verify-and-destroy.sh](./verify-and-destroy.sh) for a runnable helper script.

## Destroy & Cleanup (Stop Billing Immediately)

```bash
terraform destroy -auto-approve

# Safety verification: ensure the resource group is completely gone
az group exists --name rg-apim-net-v2
# If anything remains:
az group delete --name rg-apim-net-v2 --yes --no-wait
```

> **Note:** Azure API Management instances enter a 48-hour soft-delete state by default (soft-deleted instances do not incur charges). If you need to immediately reuse the same `apim_name`, purge it with `az apim deletedservice purge --service-name <your-apim-name> --location <location>`.

## Official Microsoft Learn References

- [What is Azure API Management?](https://learn.microsoft.com/en-us/azure/api-management/api-management-key-concepts)
- [Use a virtual network with Azure API Management](https://learn.microsoft.com/en-us/azure/api-management/virtual-network-concepts)
- [Deploy Azure API Management to a virtual network — internal mode](https://learn.microsoft.com/en-us/azure/api-management/api-management-using-with-internal-vnet)
- [Connect privately to API Management using an inbound private endpoint](https://learn.microsoft.com/en-us/azure/api-management/private-endpoint)
- [Integrate API Management in an internal VNet with Application Gateway](https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-integrate-internal-vnet-appgateway)
- [Configure Front Door Standard/Premium in front of Azure API Management](https://learn.microsoft.com/en-us/azure/api-management/front-door-api-management)
- [Self-hosted gateway overview](https://learn.microsoft.com/en-us/azure/api-management/self-hosted-gateway-overview)
