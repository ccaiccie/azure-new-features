#!/usr/bin/env bash
# Official Azure CLI equivalent for Bring-Your-Own (BYO) Application Gateway for Containers lab
# COST WARNING: AKS and Application Gateway for Containers incur hourly charges until deleted.
set -euo pipefail

RESOURCE_GROUP="${RESOURCE_GROUP:-rg-agfc-lab-disposable}"
LOCATION="${LOCATION:-eastus2}"
AKS_NAME="${AKS_NAME:-agfclab-aks}"
VNET_NAME="${VNET_NAME:-agfclab-vnet}"
AKS_SUBNET_NAME="subnet-aks"
ALB_SUBNET_NAME="subnet-alb"
AGFC_NAME="${AGFC_NAME:-agfclab-alb}"
FRONTEND_NAME="${FRONTEND_NAME:-test-frontend}"
ASSOCIATION_NAME="${ASSOCIATION_NAME:-association-test}"
IDENTITY_NAME="azure-alb-identity"
CONTROLLER_NAMESPACE="azure-alb-system"

# 1. Register required resource providers and add alb CLI extension
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.NetworkFunction
az provider register --namespace Microsoft.ServiceNetworking
az extension add --name alb --yes

# 2. Disposable resource group, VNet, AKS subnet, and delegated ALB subnet (/24 minimum)
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

az network vnet create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VNET_NAME" \
  --location "$LOCATION" \
  --address-prefixes 10.20.0.0/16 \
  --subnet-name "$AKS_SUBNET_NAME" \
  --subnet-prefixes 10.20.1.0/24

az network vnet subnet create \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name "$ALB_SUBNET_NAME" \
  --address-prefixes 10.20.2.0/24 \
  --delegations 'Microsoft.ServiceNetworking/trafficControllers'

AKS_SUBNET_ID=$(az network vnet subnet show -g "$RESOURCE_GROUP" --vnet-name "$VNET_NAME" -n "$AKS_SUBNET_NAME" --query id -o tsv)
ALB_SUBNET_ID=$(az network vnet subnet show -g "$RESOURCE_GROUP" --vnet-name "$VNET_NAME" -n "$ALB_SUBNET_NAME" --query id -o tsv)

# 3. Create AKS cluster with Azure CNI Overlay, OIDC issuer, and Workload Identity
az aks create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_NAME" \
  --location "$LOCATION" \
  --node-count 2 \
  --node-vm-size Standard_D2s_v3 \
  --network-plugin azure \
  --network-plugin-mode overlay \
  --vnet-subnet-id "$AKS_SUBNET_ID" \
  --enable-oidc-issuer \
  --enable-workload-identity \
  --generate-ssh-keys

# 4. Create User-Assigned Managed Identity, federated credential, and RBAC assignments
az identity create --resource-group "$RESOURCE_GROUP" --name "$IDENTITY_NAME"
PRINCIPAL_ID=$(az identity show -g "$RESOURCE_GROUP" -n "$IDENTITY_NAME" --query principalId -o tsv)
CLIENT_ID=$(az identity show -g "$RESOURCE_GROUP" -n "$IDENTITY_NAME" --query clientId -o tsv)
echo "Waiting 60 seconds for Entra ID identity replication..."
sleep 60

MC_RG=$(az aks show -g "$RESOURCE_GROUP" -n "$AKS_NAME" --query nodeResourceGroup -o tsv)
MC_RG_ID=$(az group show --name "$MC_RG" --query id -o tsv)
RG_ID=$(az group show --name "$RESOURCE_GROUP" --query id -o tsv)

# Reader on AKS node resource group
az role assignment create --assignee-object-id "$PRINCIPAL_ID" --assignee-principal-type ServicePrincipal --scope "$MC_RG_ID" --role "acdd72a7-3385-48ef-bd42-f606fba81ae7"
# AppGw for Containers Configuration Manager on lab RG (includes required data actions)
az role assignment create --assignee-object-id "$PRINCIPAL_ID" --assignee-principal-type ServicePrincipal --scope "$RG_ID" --role "fbc52c3f-28ad-4303-a892-8a056630b8f1"
# Network Contributor on delegated association subnet
az role assignment create --assignee-object-id "$PRINCIPAL_ID" --assignee-principal-type ServicePrincipal --scope "$ALB_SUBNET_ID" --role "4d97b98b-1d4f-4787-a291-c67834d212e7"

AKS_OIDC_ISSUER=$(az aks show -g "$RESOURCE_GROUP" -n "$AKS_NAME" --query "oidcIssuerProfile.issuerUrl" -o tsv)
az identity federated-credential create \
  --name "$IDENTITY_NAME" \
  --identity-name "$IDENTITY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --issuer "$AKS_OIDC_ISSUER" \
  --subject "system:serviceaccount:${CONTROLLER_NAMESPACE}:alb-controller-sa"

# 5. Create BYO Application Gateway for Containers parent, frontend, and association (~5-6 minutes)
az network alb create -g "$RESOURCE_GROUP" -n "$AGFC_NAME"
az network alb frontend create -g "$RESOURCE_GROUP" -n "$FRONTEND_NAME" --alb-name "$AGFC_NAME"
az network alb association create -g "$RESOURCE_GROUP" -n "$ASSOCIATION_NAME" --alb-name "$AGFC_NAME" --subnet "$ALB_SUBNET_ID"

# 6. Connect kubectl and install ALB Controller via Helm
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$AKS_NAME" --overwrite-existing
helm install alb-controller oci://mcr.microsoft.com/application-lb/charts/alb-controller \
  --namespace "$CONTROLLER_NAMESPACE" \
  --create-namespace \
  --version 1.13.1 \
  --set albController.namespace="$CONTROLLER_NAMESPACE" \
  --set albController.podIdentity.clientID="$CLIENT_ID"

echo "Done! Verify pods with: kubectl get pods -n $CONTROLLER_NAMESPACE"
