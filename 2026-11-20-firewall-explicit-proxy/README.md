# Azure Firewall explicit proxy: send web traffic to the firewall as a proxy

Terraform practice lab for the Azure New Features video "Azure Firewall Explicit Proxy: Client Web Traffic Straight to the Firewall, No UDR Needed" (YouTube playlist **azure new features**, Network Technician channel).

By default Azure Firewall works in **transparent** mode: a user-defined route (UDR) pushes traffic to the firewall, which intercepts it inline. With **explicit proxy** enabled on the firewall **policy**, a browser or application is told to use the firewall's private IP address and a port as its proxy, so web traffic reaches the firewall directly and no UDR is needed. HTTP and HTTPS destinations are served by one HTTP proxy port. Clients learn the proxy either from a manual setting or from a **PAC file** that you keep in a storage account and give to the policy as a SAS URL, together with a user-assigned managed identity.

## What it builds

| Piece | Why it matters |
| --- | --- |
| Resource group, VNet `10.30.0.0/16`, `AzureFirewallSubnet` and a `client` subnet | The client subnet has **no route table**; explicit proxy does not use a UDR |
| Storage account, private container, blob `proxy.pac` (rendered from `proxy.pac.tftpl`) | Customer-owned place where the PAC file lives |
| Read-only container SAS | The SAS URL given to the policy as `pac_file` |
| User-assigned identity `PacFileMSI-<prefix>` with *Storage Blob Data Contributor* and *Storage Blob Data Reader* on the storage account | The identity name must start with `PacFileMSI-` |
| `azurerm_firewall_policy` with `explicit_proxy` (`enabled`, `http_port`, `enable_pac_file`, `pac_file_port`, `pac_file`) | Explicit proxy is configured on the policy, not on the firewall resource |
| Application rule collection `allow-web` (HTTP 80, HTTPS 443, a short FQDN list) | Explicit proxy traffic is judged by **application rules**; a network rule does not match it |
| Azure Firewall (Standard by default, Premium supported) and its public IP | The proxy endpoint and the egress point |
| Optional Ubuntu client VM with no public IP | Used for the `curl -x` tests |

## Prerequisites

- An Azure subscription, `az login` in a terminal on your computer, and permission to create role assignments (Owner, or Contributor plus User Access Administrator).
- Terraform 1.6 or newer. Providers: `hashicorp/azurerm` 5.14.0 (pinned), `hashicorp/random`.
- Azure CLI 2.60 or newer (for `az vm run-command`).

## Cost warning

Azure Firewall bills per deployment hour plus data processed, and the VM, disk, public IP and storage add a little more. **Run `terraform destroy` when you finish.**

## Steps

```bash
cp terraform.tfvars.example terraform.tfvars   # set subscription_id
terraform init
terraform validate
terraform plan
terraform apply
terraform output
```

Notes:

- **The PAC file points at `firewall_private_ip` (default `10.30.0.4`).** Azure assigns the first usable address of `AzureFirewallSubnet`, which is the fourth address. The PAC file has to exist before the policy can reference it, and the policy has to exist before the firewall, so the address is a variable. The `check "pac_points_at_firewall"` block warns after apply if the real address differs; set the variable and apply again.
- **One port serves HTTP and HTTPS.** `https_port` is exposed by the provider for the earlier two-port design; leave `proxy_https_port` unset.
- **The SAS lives in the Terraform state.** Treat state as sensitive, keep the expiry short, and renew the SAS before it lapses.
- Changing the PAC file in the storage account does not by itself change what the firewalls serve. Re-apply the policy (and check the SAS is not expired) after you edit it.

## Verify (expected results)

1. Settings applied to the policy:

   ```bash
   terraform output explicit_proxy_settings
   az network firewall policy show -g rg-fwexp-lab -n fwexp-policy --query explicitProxy
   ```

   Expect `enableExplicitProxy: true`, `httpPort: 8080`, `enablePacFile: true`, `pacFilePort: 8090`.

2. Test from the client VM (runs `curl -x` through the proxy):

   ```bash
   eval "$(terraform output -raw test_command)"
   ```

   | Request | Expected |
   | --- | --- |
   | `https://www.microsoft.com` through the proxy | `allowed:200` (or a redirect code); the application rule allows it |
   | `https://www.example.org` through the proxy | a failure or `blocked:403`; not in the rule, so the application rule collection group denies it by default |

3. See the proof in the logs. Explicit proxy relies on application rules, so requests appear in the `AZFWApplicationRules` table. Create a diagnostic setting on the firewall that sends the resource-specific *Azure Firewall Application Rule* category to a Log Analytics workspace, then run `terraform output log_query` and paste the KQL. The `SourceIp` is the client VM and the `Fqdn` is the site you requested.

4. Optional PAC test from the VM: `curl -s http://<firewall-ip>:8090/` hits the port where the firewall serves the PAC file. The portal's *Explicit proxy* pane shows the PAC settings; the exact path served on that port is not covered here, so confirm it in your own lab.

5. Compare with transparent mode. Without a proxy setting, run `curl https://www.microsoft.com` on the VM. It goes straight to the internet through the VM's default outbound path and **never touches the firewall**, because the client subnet has no UDR. That is the key difference: with explicit proxy only clients that are configured to use the proxy are steered to the firewall.

## Troubleshooting flow

1. Can the client reach `<firewall-ip>:<proxy port>`? (`curl -x` or a TCP test; check NSGs and routing between client and firewall.)
2. Is explicit proxy enabled on the policy that the firewall actually uses? (Policy, not firewall; check child policy inheritance.)
3. Is there an **application** rule that allows the FQDN and protocol? Network rules do not match proxied traffic.
4. Is the PAC file reachable and valid? Check the SAS expiry, the `PacFileMSI-` identity, the two role assignments and the 256 KB size limit.
5. Does `AZFWApplicationRules` show the request? If not, the client is not using the proxy; if yes, read the `Action` and `Rule` columns.

## Cleanup

```bash
terraform destroy
```

## Limits and caveats (see the video for the sources)

- Supported on Azure Firewall Standard and Premium policies. The PAC file is limited to 256 KB.
- Documented for Azure Arc scenarios: the explicit proxy feature does not support TLS inspection, and TLS certificates cannot be applied to the explicit proxy. Do not assume Premium TLS inspection decrypts proxied sessions.
- The Azure Arc integration page is still marked public preview.
- Treat the port numbers (8080, 8090) and the example FQDNs as illustrative.
