# Azure API Management Networking Practice Lab

Practice Terraform and Azure CLI lab for the **Network Technician** class: **Azure API Management Networking: VNet Injection, Application Gateway, and Private Link**.

> **COST AND PROVISIONING WARNING**
> An Azure API Management instance **bills continuously until it is deleted**, and some SKUs (such as Premium and Premium v2) are expensive. Application Gateway `WAF_v2` also bills hourly while provisioned. Provisioning API Management in internal VNet mode typically takes **30 to 40 minutes** (and infrastructure updates take 15 minutes or longer). **Run `terraform destroy` as soon as you finish testing** so you do not incur ongoing charges.

## SKU Choice and Why It Is Officially Valid

This lab uses **`Developer_1`** (`Developer` tier, 1 unit) for API Management and **`WAF_v2`** (capacity 1) for Application Gateway:

- Official Microsoft Learn documentation confirms that classic **Internal VNet Injection** is supported on **Developer** and **Premium** tiers only (`Basic`, `Standard`, and `Standard v2` do not support classic VNet injection).
- `Developer_1` is the lowest-cost SKU that officially supports internal VNet injection and Application Gateway integration (Microsoft's own Application Gateway integration tutorial uses `Developer`). It is intended for non-production labs and has no SLA.
- **Public IP note (May 2024 update):** Per Microsoft Learn's internal VNet guide, a separate Public IP address resource is no longer required for internal VNet injection as of May 2024, so this lab omits it. (Note: the older PowerShell snippet on the Application Gateway how-to page still shows creating a Public IP for APIM; the current internal VNet how-to page takes precedence.)

## Architecture Built by This Lab

1. **Virtual Network (`10.20.0.0/16`)** with three subnets:
   - `snet-appgw` (`10.20.1.0/24`) — Application Gateway `WAF_v2` with required `GatewayManager` (`65200-65535`) and `Internet` (`80`, `443`) NSG rules.
   - `snet-apim` (`10.20.2.0/24`) — Internal API Management subnet with **no subnet delegation (`None`)**, service endpoints (`Storage`, `Sql`, `KeyVault`, `EventHub`), and the official minimum inbound/outbound NSG rules (`ApiManagement:3443`, `AzureLoadBalancer:6390`, App Gateway subnet `443`, plus outbound `Storage:443`, `Sql:1433`, `AzureKeyVault:443`, `AzureMonitor:1886,443`, `Internet:80`).
   - `snet-backend` (`10.20.3.0/24`) — Private backend / test VM subnet.
2. **Azure API Management (`Developer_1`, `Internal` VNet mode)** — Isolates gateway, developer portal, direct management, and Git endpoints to the VNet.
3. **Scoped Azure Private DNS Zone (`<apim_name>.azure-api.net`)** — Linked to the VNet with an `@` A record pointing to the APIM private virtual IP. Following Microsoft's critical DNS guidance, this lab does **not** create a Private DNS zone for the apex `azure-api.net` domain.
4. **Azure Application Gateway (`WAF_v2`)** — Exposes the internal API Management gateway externally with a custom HTTPS health probe on `/status-0123456789abcdef` and `pick_host_name_from_backend_address = true`. (For production, terminate HTTPS on the frontend listener using a custom domain certificate stored in Key Vault.)

## Quick Start

1. Copy the example variables file and edit `apim_name` and `publisher_email`:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
2. Sign in with Azure CLI and initialize Terraform:
   ```bash
   az login
   terraform init
   terraform plan
   terraform apply
   ```
   Wait 30 to 40 minutes for internal VNet API Management provisioning to finish.

## Verification

Run the commands in `verify-and-cleanup.sh`:
- Confirm `virtualNetworkType` is `Internal` and inspect the private IP with `az apim show`.
- Confirm Application Gateway sees the APIM backend pool as `Healthy` using `az network application-gateway show-backend-health`.
- Confirm the scoped Private DNS A record resolves to the APIM private IP.
- Call `http://<appgw_public_ip>/status-0123456789abcdef` with `curl -i` and verify HTTP `200 Service Operational`.
- In the Azure portal, open **API Management > Network > Network status** to verify all **Required** Azure dependencies are green.

## Teardown (Stop Billing)

Destroy every resource when finished:

```bash
terraform destroy
```

Verify the resource group is gone:

```bash
az group show --name rg-apim-networking-lab
```

If you tested a soft-deleted API Management name and want to reuse it immediately, remember Azure API Management retains soft-deleted instances for 48 hours unless purged with `az apim deletedservice purge`.

## Official Microsoft Learn Sources

- Using a virtual network with Azure API Management: https://learn.microsoft.com/en-us/azure/api-management/virtual-network-concepts
- Deploy Azure API Management to an internal VNet: https://learn.microsoft.com/en-us/azure/api-management/api-management-using-with-internal-vnet
- Set up an inbound private endpoint for Azure API Management: https://learn.microsoft.com/en-us/azure/api-management/private-endpoint
- Use API Management in a virtual network with Azure Application Gateway: https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-integrate-internal-vnet-appgateway
- Network resource requirements for API Management VNet injection: https://learn.microsoft.com/en-us/azure/api-management/virtual-network-injection-resources
- Inject a Premium v2 instance into a virtual network: https://learn.microsoft.com/en-us/azure/api-management/inject-vnet-v2
- Integrate an API Management instance with a private VNet for outbound connections: https://learn.microsoft.com/en-us/azure/api-management/integrate-vnet-outbound
- Configure Front Door Standard/Premium in front of API Management: https://learn.microsoft.com/en-us/azure/api-management/front-door-api-management
