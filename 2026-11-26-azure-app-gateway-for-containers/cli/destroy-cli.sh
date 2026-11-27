#!/usr/bin/env bash
# Tear down ALL Azure resources created by the CLI lab (AKS, Application Gateway for Containers,
# Association, Frontend, Managed Identity, VNet, and delegated subnet) by deleting the disposable RG.
set -euo pipefail

RESOURCE_GROUP="${RESOURCE_GROUP:-rg-agfc-lab-disposable}"

echo "Deleting Kubernetes Gateway API resources first (if cluster is still reachable)..."
kubectl delete -f ../k8s/04-healthcheck-policy.yaml --ignore-not-found || true
kubectl delete -f ../k8s/03-httproute-path-routing.yaml --ignore-not-found || true
kubectl delete -f ../k8s/02-gateway-http.yaml --ignore-not-found || true
kubectl delete -f ../k8s/01-sample-apps.yaml --ignore-not-found || true

echo "Deleting disposable resource group: $RESOURCE_GROUP"
az group delete --name "$RESOURCE_GROUP" --yes --no-wait
echo "Deletion initiated. Verify with: az group show --name $RESOURCE_GROUP"
