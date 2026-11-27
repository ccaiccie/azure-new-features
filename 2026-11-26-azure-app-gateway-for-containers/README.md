# Azure Application Gateway for Containers Practice Lab (BYO Deployment)

> **COST WARNING:** An AKS cluster and Azure Application Gateway for Containers incur hourly charges until they are deleted (AKS node compute plus Application Gateway for Containers parent, frontend, association, and capacity-unit hourly meters). Run this lab in a disposable resource group and tear down **all** resources — AKS cluster, Application Gateway for Containers parent/association/frontend, managed identity, VNet, and delegated subnet — immediately after finishing.

## Deployment Strategy Used in This Lab

This lab uses the official **Bring Your Own (BYO) deployment strategy**:
- Azure Resource Manager (via **Terraform** or **Azure CLI**) manages the lifecycle of the **Application Gateway for Containers** parent resource, **Association** resource, and **Frontend** resource.
- **ALB Controller** (installed via Helm into `azure-alb-system`) runs in AKS, authenticates with a User-Assigned Managed Identity via Workload Identity, and references the pre-created Azure resources from Kubernetes Gateway API objects (`Gateway` + `HTTPRoute`).
- Deleting the Kubernetes `Gateway` in BYO mode does **not** delete the Azure Frontend resource; Terraform or Azure CLI destroys it during teardown.

## Prerequisites

- Azure subscription with permissions to create Resource Groups, VNets, AKS clusters, Managed Identities, RBAC role assignments, and Application Gateway for Containers resources.
- Registered resource providers:
  ```bash
  az provider register --namespace Microsoft.ContainerService
  az provider register --namespace Microsoft.Network
  az provider register --namespace Microsoft.NetworkFunction
  az provider register --namespace Microsoft.ServiceNetworking
  az extension add --name alb
  ```
- Tools installed locally (or in Azure Cloud Shell): `az`, `terraform` (>= 1.6), `kubectl`, `helm` (v3), `curl`, `envsubst`.
- Pick a supported region from the [official overview](https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/overview) (default in this lab: `eastus2`).

## Option A: Deploy Infrastructure with Terraform

1. Copy the example variables file and edit if desired:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
2. Initialize and apply (creating the Association takes roughly 5 to 6 minutes):
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```
3. Export the outputs needed for Helm and Kubernetes Gateway API:
   ```bash
   export RESOURCE_GROUP=$(terraform output -raw resource_group_name)
   export AKS_NAME=$(terraform output -raw aks_cluster_name)
   export ALB_CLIENT_ID=$(terraform output -raw alb_identity_client_id)
   export AGFC_RESOURCE_ID=$(terraform output -raw agfc_resource_id)
   export FRONTEND_NAME=$(terraform output -raw agfc_frontend_name)
   ```
4. Connect `kubectl` and install ALB Controller with Helm:
   ```bash
   az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$AKS_NAME" --overwrite-existing
   helm install alb-controller oci://mcr.microsoft.com/application-lb/charts/alb-controller \
     --namespace azure-alb-system \
     --create-namespace \
     --version 1.13.1 \
     --set albController.namespace=azure-alb-system \
     --set albController.podIdentity.clientID="$ALB_CLIENT_ID"
   ```
5. Verify both ALB Controller pods (`alb-controller` and `alb-controller-bootstrap`) are running and the `azure-alb-external` GatewayClass is accepted:
   ```bash
   kubectl get pods -n azure-alb-system
   kubectl get gatewayclass azure-alb-external -o yaml
   ```

## Option B: Deploy Infrastructure with Azure CLI

Run the equivalent official CLI script in `cli/deploy-cli.sh`:
```bash
chmod +x cli/deploy-cli.sh
./cli/deploy-cli.sh
```
Then export `AGFC_RESOURCE_ID` and `FRONTEND_NAME`:
```bash
export AGFC_RESOURCE_ID=$(az network alb show -g rg-agfc-lab-disposable -n agfclab-alb --query id -o tsv)
export FRONTEND_NAME="test-frontend"
```

## Deploy Sample Apps, Gateway, HTTPRoute & Custom Health Probe

1. Deploy the `backend-v1` and `backend-v2` sample services:
   ```bash
   kubectl apply -f k8s/01-sample-apps.yaml
   ```
2. Deploy the BYO Gateway API `Gateway` (port 80 HTTP first step):
   ```bash
   envsubst < k8s/02-gateway-http.yaml | kubectl apply -f -
   kubectl get gateway gateway-01 -n test-infra -o yaml
   ```
   Wait until `Accepted=True`, `Programmed=True`, and `.status.addresses[0].value` shows the `*.fzXX.alb.azure.com` Frontend FQDN.
3. Deploy the `HTTPRoute` (path, header, query string, and default routing) and optional custom `HealthCheckPolicy`:
   ```bash
   kubectl apply -f k8s/03-httproute-path-routing.yaml
   kubectl apply -f k8s/04-healthcheck-policy.yaml
   kubectl get httproute http-route -n test-infra -o yaml
   ```

> **Optional TLS step:** Certificates for Application Gateway for Containers must be stored as Kubernetes Secrets (Azure Key Vault CSI driver is not supported; use `cert-manager` or a lab TLS secret). See the official [SSL offloading how-to](https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/how-to-ssl-offloading-gateway-api) and [End-to-End TLS how-to](https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/how-to-end-to-end-tls-gateway-api) to switch the listener to port 443 HTTPS.

## Verification

Fetch the Frontend FQDN and test all three routes:
```bash
FQDN=$(kubectl get gateway gateway-01 -n test-infra -o jsonpath='{.status.addresses[0].value}')

# 1. Path-based routing -> backend-v2
curl -s "http://${FQDN}/bar" | grep -i "Hostname"

# 2. Header + query string + path + GET routing -> backend-v2
curl -s "http://${FQDN}/some/thing?great=example" -H "magic: foo" | grep -i "Hostname"

# 3. Default route -> backend-v1
curl -s "http://${FQDN}/" | grep -i "Hostname"
```

## Teardown (Destroy Everything to Stop Billing)

### If you deployed with Terraform
```bash
kubectl delete -f k8s/04-healthcheck-policy.yaml --ignore-not-found
kubectl delete -f k8s/03-httproute-path-routing.yaml --ignore-not-found
kubectl delete -f k8s/02-gateway-http.yaml --ignore-not-found
kubectl delete -f k8s/01-sample-apps.yaml --ignore-not-found
terraform destroy
```

### If you deployed with Azure CLI
```bash
chmod +x cli/destroy-cli.sh
./cli/destroy-cli.sh
```

Verify the disposable resource group and all child resources (AKS, Application Gateway for Containers, Association, Frontend, Managed Identity, VNet, and delegated subnet) are deleted:
```bash
az group show --name rg-agfc-lab-disposable
```

## Official Sources

- What is Application Gateway for Containers: https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/overview
- Application Gateway for Containers components: https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/application-gateway-for-containers-components
- Deploy ALB Controller (Helm): https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/quickstart-deploy-application-gateway-for-containers-alb-controller-helm
- Deploy ALB Controller (AKS Add-on): https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/quickstart-deploy-application-gateway-for-containers-alb-controller-addon
- Create Application Gateway for Containers (BYO): https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/quickstart-create-application-gateway-for-containers-byo-deployment
- Create Application Gateway for Containers (ALB-managed): https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/quickstart-create-application-gateway-for-containers-managed-by-alb-controller
- Path, header, and query string routing (Gateway API): https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/how-to-path-header-query-string-routing-gateway-api
- Custom health probe: https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/custom-health-probe
- SSL offloading (Gateway API): https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/how-to-ssl-offloading-gateway-api
- End-to-End TLS (Gateway API): https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/how-to-end-to-end-tls-gateway-api
- Azure WAF on Application Gateway for Containers: https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/web-application-firewall
- Understanding pricing: https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/understanding-pricing
