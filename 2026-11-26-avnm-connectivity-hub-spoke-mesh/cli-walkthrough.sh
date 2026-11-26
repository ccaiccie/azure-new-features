#!/usr/bin/env bash
# Azure CLI walkthrough for AVNM Connectivity Configurations (Mesh & Hub-and-Spoke)
# Run in your own Azure subscription after `az login` and `az account set --subscription <SUB_ID>`

set -euo pipefail

LOCATION="${LOCATION:-westus2}"
RG="${RG:-rg-avnm-cli-lab}"
AVNM="${AVNM:-avnm-cli-lab}"
SUB_ID=$(az account show --query id -o tsv)

# 1. Install or update the Azure Virtual Network Manager CLI extension
az extension add -n virtual-network-manager --upgrade

# 2. Create resource group and 3 VNets (1 Hub + 2 Spokes)
az group create --name "$RG" --location "$LOCATION"

az network vnet create --name vnet-hub     --resource-group "$RG" --location "$LOCATION" --address-prefix 10.0.0.0/16 --subnet-name snet-workload --subnet-prefix 10.0.0.0/24
az network vnet create --name vnet-spoke-a --resource-group "$RG" --location "$LOCATION" --address-prefix 10.1.0.0/16 --subnet-name snet-workload --subnet-prefix 10.1.0.0/24
az network vnet create --name vnet-spoke-b --resource-group "$RG" --location "$LOCATION" --address-prefix 10.2.0.0/16 --subnet-name snet-workload --subnet-prefix 10.2.0.0/24

# 3. Create Azure Virtual Network Manager instance (Connectivity scope)
az network manager create \
  --location "$LOCATION" \
  --name "$AVNM" \
  --resource-group "$RG" \
  --scope-accesses "Connectivity" \
  --network-manager-scopes subscriptions="/subscriptions/$SUB_ID"

# 4. Create a Network Group and add Spokes as static members
az network manager group create \
  --name ng-spokes \
  --network-manager-name "$AVNM" \
  --resource-group "$RG" \
  --description "Spoke virtual networks"

NG_ID="/subscriptions/$SUB_ID/resourceGroups/$RG/providers/Microsoft.Network/networkManagers/$AVNM/networkGroups/ng-spokes"
SPOKE_A_ID=$(az network vnet show -g "$RG" -n vnet-spoke-a --query id -o tsv)
SPOKE_B_ID=$(az network vnet show -g "$RG" -n vnet-spoke-b --query id -o tsv)
HUB_ID=$(az network vnet show -g "$RG" -n vnet-hub --query id -o tsv)

az network manager group static-member create \
  --name member-spoke-a --network-group ng-spokes --network-manager "$AVNM" \
  --resource-group "$RG" --resource-id "$SPOKE_A_ID"

az network manager group static-member create \
  --name member-spoke-b --network-group ng-spokes --network-manager "$AVNM" \
  --resource-group "$RG" --resource-id "$SPOKE_B_ID"

# 5A. Create a Mesh connectivity configuration
az network manager connect-config create \
  --configuration-name cc-mesh \
  --network-manager-name "$AVNM" \
  --resource-group "$RG" \
  --connectivity-topology Mesh \
  --applies-to-groups "[{\"networkGroupId\":\"$NG_ID\",\"groupConnectivity\":\"None\"}]"

# 5B. Create a Hub-and-Spoke connectivity configuration with Direct Connectivity
az network manager connect-config create \
  --configuration-name cc-hub-spoke \
  --network-manager-name "$AVNM" \
  --resource-group "$RG" \
  --connectivity-topology HubAndSpoke \
  --hub "{\"resourceId\":\"$HUB_ID\",\"resourceType\":\"Microsoft.Network/virtualNetworks\"}" \
  --applies-to-groups "[{\"networkGroupId\":\"$NG_ID\",\"groupConnectivity\":\"DirectlyConnected\",\"useHubGateway\":\"False\"}]"

# 6. Commit Mesh deployment to target region
CC_MESH_ID="/subscriptions/$SUB_ID/resourceGroups/$RG/providers/Microsoft.Network/networkManagers/$AVNM/connectivityConfigurations/cc-mesh"
az network manager post-commit \
  --network-manager-name "$AVNM" \
  --resource-group "$RG" \
  --commit-type Connectivity \
  --configuration-ids "$CC_MESH_ID" \
  --target-locations "$LOCATION"

# 7. Verify effective connectivity configuration on spoke VNets
az network manager list-effective-connectivity-config \
  --resource-group "$RG" --virtual-network-name vnet-spoke-a

# 8. Remove all deployed connectivity configurations (Goal State = None)
# az network manager post-commit \
#   --network-manager-name "$AVNM" --resource-group "$RG" \
#   --commit-type Connectivity --configuration-ids "" --target-locations "$LOCATION"

# 9. Clean up everything so charges stop
# az group delete --name "$RG" --yes --no-wait
