# AI Security add-on for Azure Firewall Premium (public preview)

Companion Terraform lab for the Network Technician lesson on the **AI Security add-on for Azure Firewall Premium**, announced at Microsoft Ignite on 17 November 2026 and documented as a public preview.

This folder builds the hub-and-spoke path the video walks through: a spoke virtual network whose default route sends egress to **Azure Firewall Premium** in the hub, with **TLS inspection** and **IDPS** configured in a Premium firewall policy. After apply, you enable the AI Security add-on and its protections in the Azure portal.

## What Terraform creates

- A resource group (default region: West Central US, one of the documented preview regions).
- Hub virtual network `10.10.0.0/16` with `AzureFirewallSubnet` (`10.10.0.0/24`).
- Spoke virtual network `10.20.0.0/16` with a `workload` subnet, plus bidirectional peering with forwarded traffic allowed.
- Azure Firewall Premium (`AZFW_VNet`) and a Standard public IP.
- A Premium firewall policy with:
  - a user-assigned managed identity
  - **TLS inspection** using an intermediate CA certificate stored as a Key Vault secret (password-less PFX), which is the approach azurerm supports
  - **IDPS** (default mode: `Alert`)
  - threat intelligence in `Alert`
  - an **HTTPS application rule** with `terminate_tls = true` for the destination FQDNs you list
- A spoke route table whose `0.0.0.0/0` next hop is the firewall's private IP, associated with the workload subnet.
- Log Analytics plus firewall diagnostic settings, so you can later enable Policy Analytics (a Policy Advisor prerequisite) in the portal.

There is no test virtual machine in this lab, to keep the bill closer to the firewall itself. Attach your own workload to the spoke subnet, and install `rootCA.crt` on that client so TLS inspection is trusted.

## Honest limit: the AI Security add-on is not in azurerm yet

Checked against the current `hashicorp/azurerm` documentation for `azurerm_firewall`, `azurerm_firewall_policy`, and `azurerm_firewall_policy_rule_collection_group` (API version `Microsoft.Network` 2025-07-01 in provider 5.14.0). There is **no argument** for the AI Security add-on, security profile groups, Prompt Threat Protection, network DLP, Advanced Malware Threat Protection, Advanced Application Threat Protection, or Policy Advisor.

Microsoft's Azure Firewall AI Security concepts page states the same thing for the preview: you configure the add-on and its protections in the **Azure portal**. Azure PowerShell, Azure CLI, Terraform, and the REST API are **not supported** for this configuration yet. This lab does not invent those resources.

Enabling the add-on on an existing firewall **requires downtime**. Plan a maintenance window.

During the preview, Microsoft documents the add-on in these regions: **East Asia**, **UK South**, and **West Central US**. Confirm the list in [Azure Firewall AI Security concepts](https://learn.microsoft.com/en-us/azure/firewall/ai-security-concepts) before you deploy.

## Prerequisites

- An Azure subscription and permission to create networking, Key Vault, and Azure Firewall Premium resources. Firewall Premium is a paid SKU; the AI Security add-on is licensed separately. Check [Azure Firewall pricing](https://azure.microsoft.com/pricing/details/azure-firewall/).
- Terraform >= 1.6 and the `hashicorp/azurerm` provider 5.14.0.
- `openssl` on the machine that generates the lab CA (used only for a test certificate).

## 1. Generate a test intermediate CA

For production, use your corporate PKI. For this lab, `cert.sh` and `openssl.cnf` follow Microsoft's published test scripts in [Azure Firewall Premium certificates](https://learn.microsoft.com/en-us/azure/firewall/premium-certificates):

```bash
chmod +x cert.sh
./cert.sh
```

That writes `interCA.pfx` (password-less) and `rootCA.crt`. Install `rootCA.crt` on any test client. Do not commit the keys or the PFX; they are gitignored.

## 2. Apply the lab

```bash
cp terraform.tfvars.example terraform.tfvars
# set subscription_id, and intermediate_ca_pfx_path = "./interCA.pfx"
terraform init
terraform plan
terraform apply
```

After apply, note the outputs: `firewall_name`, `firewall_policy_name`, `firewall_private_ip`, and `log_analytics_workspace_id`.

## 3. Enable the AI Security add-on (portal)

Do this in a maintenance window.

1. In the Azure portal, open the Premium firewall this lab created.
2. Enable the **AI Security** add-on on that firewall. If a policy is associated with more than one firewall, enable the add-on on every associated firewall before you configure protections.
3. Wait until the firewall is ready again.

Microsoft documents that enabling the add-on alone does not mean a flow was inspected. Traffic must also be routed through the firewall, match the application rule, use a security profile group, and (for HTTPS) decrypt successfully.

## 4. Configure protections (portal)

Open the **firewall policy**. During the preview, create **Security profile groups** and attach them to the HTTPS application rule (`inspected-https` / `https-with-tls-inspection`). Start every profile in **Alert only**, then move to **Alert and deny** after you have a logged verdict, not just a successful transfer.

### Prompt Threat Protection

1. Create a group and add a Prompt Threat Protection profile.
2. Set mode to Alert only. Keep direction as request. Review the failure action (the portal default is fail open).
3. Enter your Azure AI Content Safety endpoint and a managed identity the policy can use to access it.
4. Choose a predefined provider schema (for example OpenAI) or a custom schema that names the JSON fields that hold the prompt.
5. Attach the group to the HTTPS application rule (TLS inspection is already enabled on that rule).
6. Test with a benign request and an approved test request. A detected attempt in Alert and deny returns HTTP 403 and does not reach the AI service.

Docs: [Prompt Threat Protection concepts](https://learn.microsoft.com/en-us/azure/firewall/prompt-threat-protection) and [Configure Prompt Threat Protection](https://learn.microsoft.com/en-us/azure/firewall/configure-prompt-threat-protection).

### Network DLP (Microsoft Purview)

Prerequisites include a Purview license and policy, the Purview tenant GUID, working TLS inspection, and a CSV that maps source IP addresses or CIDR ranges to Microsoft Entra user object IDs, hosted at a URL a managed identity can read (Storage Blob Data Contributor on that container). Only mapped traffic is inspected. Maximum content size is 3 MB; if inspection cannot complete, traffic is allowed (fail-open).

1. In Purview, create a DLP policy for inline web traffic, start in simulation or audit, then Block when you are ready.
2. In the firewall policy, create a group with a Data loss prevention profile: mode Alert only, provider Microsoft Purview, tenant GUID, mapping file URL, and managed identity.
3. Attach the group to the application rule. After you have evidence of evaluation, switch the profile to Alert and deny and the Purview rule to Block.

Docs: [Configure network DLP](https://learn.microsoft.com/en-us/azure/firewall/configure-network-dlp).

### Advanced Malware Threat Protection

Create a malware profile in a group, start in Alert only, set an alert risk threshold, and attach the group to the application rule. The preview inspects individual Windows PE files (`.exe`, `.dll`) up to 128 KB in outbound and east-west traffic. Inbound is outside the initial scope. Verdicts are probabilistic.

Docs: [Configure Advanced Malware Threat Protection](https://learn.microsoft.com/en-us/azure/firewall/configure-malware-protection).

### Advanced Application Threat Protection

Create an application-threat profile, start in Alert only, set an alert threshold, and attach it to the application rule. The preview inspects about 1–2 KB of HTTP request content (method, URL, selected headers, and body). Inbound DNAT traffic is not inspected. A deny returns HTTP 403. This complements, and does not replace, Azure Web Application Firewall.

Docs: [Configure Advanced Application Threat Protection](https://learn.microsoft.com/en-us/azure/firewall/configure-application-threat-protection).

### Policy Advisor and a dry-run

Policy Advisor is not a packet-path check. It adds findings to Policy Analytics (anomaly detection, rule hygiene, and traffic analysis: unused, duplicate, shadowed, or overlapping rules, traffic surges, newly observed flows). It analyzes configuration plus traffic logs, runs daily, and **does not change the policy**. Review the evidence; an unused rule may still be required.

1. Enable **Policy Analytics** on the policy and point it at the Log Analytics workspace this lab created (the same workspace already used in diagnostic settings). Logs can take about 60 minutes to appear the first time.
2. Attach a managed identity to the policy with access to that workspace, and confirm the AI Security add-on is enabled on every associated firewall.
3. Review findings when they appear. Microsoft's announcement says to validate changes with a dry-run before applying them. Use **Draft & Deployment**: create a draft (a clone of the live policy), make the change there, review it, and deploy only when you are ready. The live policy is unchanged until you deploy. Only one draft can exist at a time; deploying a draft replaces the entire applied policy.

Docs: [Policy Analytics, including Policy Advisor](https://learn.microsoft.com/en-us/azure/firewall/policy-analytics) and [Draft + Deployment](https://learn.microsoft.com/en-us/azure/firewall/draft-deploy).

## Things that will skip inspection

- A **matching network rule** is evaluated before application rules, so the HTTPS rule and every AI Security profile would be skipped. This lab does not create a wide network allow; do not add one unless you intend to bypass application-layer inspection.
- TLS inspection failure, or a client that does not trust `rootCA.crt`.
- Add-on enabled, but no security profile group on the application rule, or a profile still set to Disabled.
- For prompts: a provider schema that does not match the request body.
- For DLP: a source IP that is not in the mapping file, or a user outside the Purview policy scope.
- A successful transfer is not evidence that a protection ran. Look for the verdict in the logs.

## Clean up

```bash
terraform destroy
```

Also remove the test CA files if you no longer need them, and any portal-only add-on or Purview configuration that Terraform does not manage.

## Sources

- [AZ580694 — Public Preview: AI Security add-on for Azure Firewall Premium](https://mc.merill.net/message/AZ580694)
- [Azure Firewall preview features](https://learn.microsoft.com/en-us/azure/firewall/firewall-preview)
- [Azure Firewall AI Security concepts](https://learn.microsoft.com/en-us/azure/firewall/ai-security-concepts)
- [Prompt Threat Protection concepts](https://learn.microsoft.com/en-us/azure/firewall/prompt-threat-protection)
- [Configure network DLP](https://learn.microsoft.com/en-us/azure/firewall/configure-network-dlp)
- [Configure Advanced Malware Threat Protection](https://learn.microsoft.com/en-us/azure/firewall/configure-malware-protection)
- [Configure Advanced Application Threat Protection](https://learn.microsoft.com/en-us/azure/firewall/configure-application-threat-protection)
- [Policy Analytics (Policy Advisor)](https://learn.microsoft.com/en-us/azure/firewall/policy-analytics)
- [Azure Firewall Premium certificates](https://learn.microsoft.com/en-us/azure/firewall/premium-certificates)
- [Draft + Deployment](https://learn.microsoft.com/en-us/azure/firewall/draft-deploy)
- [azurerm_firewall_policy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall_policy)
