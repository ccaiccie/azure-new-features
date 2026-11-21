# Azure Firewall for Containers (public preview) — Terraform lab

Companion lab for the Network Technician lesson on Azure Firewall for Containers.

This folder deploys the Azure-side foundation for the **existing-firewall path** documented in [Deploy Azure Firewall for Containers (preview)](https://learn.microsoft.com/en-us/azure/firewall/deploy-firewall-for-containers): a virtual network, the required firewall subnets and public IP addresses, a Premium Azure Firewall that already uses a Firewall Policy (not classic rules), the required AKS and `*.afc.azure.com` egress allows, a user-assigned managed identity with Network Contributor, and a route table that points the default route at the firewall private IP.

It does **not** create an AKS cluster, install the Azure Firewall Controller, or apply the Kubernetes custom resources. Those steps are not representable in azurerm 5.14.0; they stay in kubectl and Helm after you create a qualifying cluster.

Official sources:

- https://mc.merill.net/message/AZ581963
- https://learn.microsoft.com/en-us/azure/firewall/deploy-firewall-for-containers
- https://learn.microsoft.com/en-us/azure/firewall/quick-create-containers-template

## Status and limits (do not skip)

- Public preview. Preview terms apply. The custom resources use `v1alpha1` and can change before general availability.
- Official deployment guidance is for **Azure Kubernetes Service** with **Azure CNI** in your own virtual network. Azure CNI Overlay is **not** supported (`networkPlugin` must be `azure` and `networkPluginMode` must not be set). The published how-to and quickstart do not document Azure Container Apps, Azure Container Instances, or other orchestrators as targets for this controller.
- The preview inspects **pod egress only** and supports **IPv4 only**. Host-network pods use the node IP and cannot be selected individually.
- Each AKS cluster supports only one `SecurityPolicyAttachment` and one Azure Firewall. Each firewall supports only one cluster.
- Azure public cloud only, in these regions: `centraluseuap`, `eastus2euap`, `westcentralus`, `eastasia`, `uksouth`, `centralus`. Use a region enabled for your preview subscription.
- Managed controller-created firewalls default to the Premium SKU. This lab also uses Premium so IDPS, TLS inspection, and URL filtering remain available if you add them later in a SecurityPolicy. A Standard SKU existing firewall can still do label-based rules, but those Premium-only features are not available.
- Changing an AKS subnet route table or the cluster outbound type can interrupt connectivity. Use an isolated evaluation environment, record the current configuration, and have a rollback plan. Associating a route table does not by itself change AKS `outboundType`.
- **Configure routing before you attach a policy.** Attachment turns off pod SNAT so the firewall sees pod IPs. Without the firewall route, pods can lose outbound connectivity.
- Azure Firewall Premium incurs charges while it exists. Run `terraform destroy` when you finish.

## Provider gaps (azurerm 5.14.0)

These official pieces have **no** azurerm 5.14.0 resources. This lab does not invent them:

- The Azure Firewall Controller Helm chart (`oci://mcr.microsoft.com/firewall/charts/azurefirewall-controller`). The Learn article used for the lesson pins controller version `20261109.1` and tells you to keep that version as shown.
- The `v1alpha1` custom resources: `AzureFirewall`, `SecurityPolicy`, and `SecurityPolicyAttachment` (`apiVersion: firewall.networking.azure.io/v1alpha1`).
- A federated identity credential, because that requires the AKS OIDC issuer URL, which this lab does not create.

The existing-firewall path is the one Terraform can express honestly: a Premium firewall that already uses a Firewall Policy, with the required base-policy rules. The controller does not modify a supplied base policy, so those allows are in this configuration.

## What Terraform creates

- Resource group (default location `centralus`)
- Virtual network `10.224.0.0/16`
- `aks-subnet` (`10.224.0.0/22`) for a later Azure CNI cluster
- `AzureFirewallSubnet` and `AzureFirewallManagementSubnet` (required names) with `/26` prefixes
- Two Standard, static, IPv4 public IP addresses (data plane and management)
- Premium Firewall Policy that does not inherit from another policy, plus a rule collection group that allows:
  - TCP 443 to the `AzureKubernetesService` service tag
  - HTTPS 443 to the `AzureKubernetesService` FQDN tag
  - HTTPS 443 to `*.afc.azure.com`
- Premium Azure Firewall (`AZFW_VNet`) using that policy, with a management IP configuration
- User-assigned managed identity and a Network Contributor role assignment on the resource group
- Route table `to-firewall` (`0.0.0.0/0` via the firewall private IP). This lab **does not** associate the table with `aks-subnet`. Associate it only after the firewall is running, you have a cluster, and you are ready to attach a policy.

## Deploy the Azure resources

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit location if needed; it must be a listed preview region.
terraform init
terraform plan
terraform apply
```

`terraform validate` is expected to succeed against azurerm 5.14.0.

## After apply: AKS, Helm, and custom resources

Create or use an AKS cluster in the same virtual network, on `aks-subnet`, with:

- `--network-plugin azure` and no Overlay mode
- `--enable-oidc-issuer` and `--enable-workload-identity`
- An outbound path that still works while you install the controller

Then follow the Learn article for the remaining steps. In short:

1. Create a federated credential on the lab identity. The subject must match the Helm namespace and the chart service account, for example `system:serviceaccount:firewall-namespace:azurefirewall-controller-sa`.
2. Install the controller:

   ```bash
   helm install azfw-controller \
     oci://mcr.microsoft.com/firewall/charts/azurefirewall-controller \
     --namespace firewall-namespace \
     --version 20261109.1 \
     --set "azfwController.podIdentity.clientID=<controller_identity_client_id>" \
     --create-namespace
   ```

   Confirm the version in the current Learn article before you install. Use the value the article says to keep as shown if it has changed.
3. Apply a `SecurityPolicy`. It does nothing until it is attached.
4. Associate the lab route table with `aks-subnet` and confirm node connectivity. Do this **before** attachment.
5. Apply a `SecurityPolicyAttachment` that references the policy, uses `firewallRef.id` set to the `firewall_id` output, and lists `aks_subnet_id` under `aksWorkloadSubnets`. Wait until the attachment `Deployment` condition **reason** is `Ready`, not only until the condition status is true.

On the first attachment, the controller creates `kube-system/azure-ip-masq-agent-config` to turn off pod SNAT. If you already have a custom ip-masq-agent configuration, make sure it does not masquerade this egress.

Do not edit the controller-managed child policy in the Azure portal. Kubernetes is its source of truth. You may change the parent policy in the portal; the controller does not undo those parent-policy changes.

Keep the controller running while you delete resources it manages. After you delete an attachment, wait about 90 seconds for pod SNAT to be restored. Then `terraform destroy` the Azure resources so you are not billed for an idle Premium firewall.

There is also an official ARM template quickstart if you prefer Microsoft’s template, including an optional script that installs the controller and a sample policy: [Quickstart: Deploy Azure Firewall for Containers with Azure Resource Manager](https://learn.microsoft.com/en-us/azure/firewall/quick-create-containers-template).
