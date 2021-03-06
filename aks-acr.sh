#!/bin/bash

GROUPNAME=""
LOCATION=""
AKSNAME=""
ACRNAME="" # must be globally unique
SUBID=""

### get version by running
### az aks get-versions --location $LOCATION --output table
k8sversion=""

# create rbac username and password
az ad sp create-for-rbac --skip-assignment -o yaml > temp

sleep 5


APPID=$(grep appId temp | awk '{ print $2;}')
PASS=$(grep password temp | awk '{ print $2;}')

echo $APPID
echo $PASS

sleep 5

# create resource group based on groupname variable
az group create --subscription $SUBID --name $GROUPNAME --location $LOCATION

sleep 2

# create aks cluster

echo "Creating cluster, this could take a few mins"

az aks create --subscription $SUBID --resource-group $GROUPNAME --name $AKSNAME \
--enable-addons monitoring,http_application_routing \
--kubernetes-version $k8sversion  --generate-ssh-keys \
--service-principal $APPID --client-secret $PASS

# get the aks cluster pass for kubectl access

az aks get-credentials --subscription $SUBID --resource-group $GROUPNAME --n $AKSNAME

echo "cluster creds for are imported"

# create an azure container registry for images, admin enabled for docker login

az acr create --subscription $SUBID --resource-group $GROUPNAME --name $ACRNAME --sku Standard --admin-enabled true

# creating RBAC for Azure AD to permit build and pull from acr to aks cluster

# Get the id of the service principal configured for AKS
CLIENT_ID=$(az aks show --subscription $SUBID --resource-group $GROUPNAME --name $AKSNAME --query "servicePrincipalProfile.clientId" --output tsv)

 # Get the ACR registry resource id
ACR_ID=$(az acr show --subscription $SUBID --name $ACRNAME --resource-group $GROUPNAME --query "id" --output tsv)

# Create role assignment
az role assignment create --subscription $SUBID --assignee $CLIENT_ID --role acrpull --scope $ACR_ID

echo "your cluster is now ready to use, check the portal for more details"

kubectl get nodes
cat temp
echo "Keep these credentials for future use"

rm temp
