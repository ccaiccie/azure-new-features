# Practice Lab: Microsoft Entra Private Access (Global Secure Access)

This practice lab pairs a compact **Terraform Azure infrastructure deployment** with the **official Microsoft Entra admin center / Global Secure Access configuration steps** so you can stand up a private network connector, publish Quick Access and a granular per-app segment, attach Conditional Access, verify access with the Global Secure Access Client, and tear everything down cleanly.

Intended public repository path:
`https://github.com/ccaiccie/azure-new-features/tree/main/2026-11-26-entra-private-access-gsa`

## Honest Boundary: Terraform vs Entra Admin Center / Graph

- **Terraform (`lab/main.tf`) creates the Azure networking and VMs:**
  - Resource Group, Azure VNet (`10.70.0.0/16`), private subnet (`10.70.1.0/24`)
  - Network Security Group allowing outbound TCP 443 and 80 for the connector (zero inbound internet ports on the private target VM)
  - **Windows Server 2022** connector host VM (`gsa-connector-vm`, meets Windows Server 2016+, .NET 4.7.2+, TLS 1.2 prerequisites)
  - **Private Ubuntu target VM** (`gsa-private-app`, no public IP, running a lightweight internal HTTP test page on TCP 80)
- **Microsoft Entra Admin Center (or Microsoft Graph) configures Global Secure Access objects:**
  - Installing & registering the Microsoft Entra private network connector (`v1.5.3417.0+`) into a connector group
  - Publishing **Quick Access** and/or a **per-app Private Access enterprise app**
  - Creating the **Conditional Access** policy (`Report-only` -> `On`)
  - Enabling the **Private Access traffic forwarding profile**

## Prerequisites

- Azure subscription + Microsoft Entra tenant with **Microsoft Entra ID P1/P2** and **Microsoft Entra Private Access** (or **Microsoft Entra Suite** / trial) licenses.
- Entra roles: **Global Secure Access Administrator**, **Application Administrator**, and **Conditional Access Administrator**.
- Terraform `>= 1.6` and Azure CLI (`az login`).
- **Never commit `terraform.tfvars`, passwords, certificates, or connector credentials.**

## Step 1: Deploy Azure Lab VNet, Connector Host & Private Target

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your subscription_id, location, and strong admin password

az login
terraform init
terraform plan -out tfplan
terraform apply tfplan
```

Note the private IP of `gsa-private-app` from `terraform output private_target_ip` (for example `10.70.1.5`).

## Step 2: Install & Register the Private Network Connector

1. Sign in to `gsa-connector-vm` (for example via Azure Bastion or a temporary JIT RDP rule — never leave RDP open to the internet).
2. In the **Microsoft Entra admin center**, go to **Global Secure Access > Connect > Connectors** and download the **Microsoft Entra private network connector** (`>= 1.5.3417.0`).
3. Run the installer on `gsa-connector-vm` and sign in with an **Application Administrator** account.
4. Create a connector group (for example `Lab-EastUS2-Connectors`) and assign `gsa-connector-vm` to it. Confirm status is **Active**.

## Step 3: Publish Quick Access (or a Granular Per-App Segment)

1. Go to **Global Secure Access > Applications > Quick access** (or **Enterprise applications > New application** for per-app access).
2. Name the app (for example `Quick Access`), select `Lab-EastUS2-Connectors`, and click **Save**.
3. Under **Network access properties > Create application segment**, add:
   - Destination type: **IP address** -> `10.70.1.5` (from `terraform output private_target_ip`), Port `80`, Protocol `TCP` (or CIDR `10.70.1.0/24`, ports `0-52,54-65535`, TCP/UDP for VPN-replacement style Quick Access + Private DNS suffix).
4. Under **Users and groups**, assign your test user directly (or a directly assigned group — **nested groups are not supported**).

## Step 4: Apply Conditional Access (Report-Only -> On)

1. Go to **Global Secure Access > Applications > Enterprise applications**, select your Quick Access or Private Access app, then select **Conditional Access > New policy**.
2. **Users:** Include your test group (or All users) and **Exclude** your **emergency access / break-glass accounts** and service accounts.
3. **Grant:** Require multifactor authentication (and optionally Require device to be marked as compliant / Microsoft Entra hybrid joined device).
4. Set **Enable policy** to **Report-only**, test and review sign-in logs, then switch to **On**.

## Step 5: Enable Private Access Forwarding Profile & Verify With GSA Client

1. Go to **Global Secure Access > Connect > Traffic forwarding** and enable the **Private access profile** (assign your test user/group).
2. Install the **Global Secure Access Client** on your Windows (or macOS/iOS/Android) test device and sign in.
3. Wait up to 5 minutes (or refresh profile), then open `http://10.70.1.5` from the client — with no VPN client running!
4. Right-click the GSA tray icon -> **Advanced diagnostics > Traffic > Start collecting**, reload `http://10.70.1.5`, stop collecting, and confirm **`Action == Tunnel`**.

## Step 6: Full Cleanup & Teardown

1. **In Microsoft Entra admin center:**
   - Delete or disable the lab **Conditional Access policy**.
   - Delete the lab **Quick Access** / **Private Access** test app and uninstall/remove the lab **private network connector** and connector group.
   - Disable the **Private access** traffic forwarding profile if not used elsewhere.
2. **Destroy Azure infrastructure:**
   ```bash
   terraform destroy
   az group exists --name "$(terraform output -raw resource_group_name)"  # Expect: false
   ```

## Official Microsoft Learn Sources

- Global Secure Access overview: https://learn.microsoft.com/en-us/entra/global-secure-access/overview-what-is-global-secure-access
- Microsoft Entra Private Access concept: https://learn.microsoft.com/en-us/entra/global-secure-access/concept-private-access
- Configure private network connectors: https://learn.microsoft.com/en-us/entra/global-secure-access/how-to-configure-connectors
- Configure Quick Access: https://learn.microsoft.com/en-us/entra/global-secure-access/how-to-configure-quick-access
- Apply Conditional Access to Private Access apps: https://learn.microsoft.com/en-us/entra/global-secure-access/how-to-target-resource-private-access-apps
- Tutorial: VPN replacement with Quick Access: https://learn.microsoft.com/en-us/entra/global-secure-access/tutorial-private-access-vpn-replacement
