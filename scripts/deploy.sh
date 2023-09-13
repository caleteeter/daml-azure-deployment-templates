#!/bin/bash
# set -euo pipefail

managedIdentity="${1}"
resourceGroupName="${2}"
aksClusterName="${3}"
acrName="${4}"
company="${5}"
username="${6}"
password="${7}"
version="${8}"
serverName="${9}"
administratorLogin="${10}"
administratorLoginPassword="${11}"

artifactsBaseUrl="https://raw.githubusercontent.com/caleteeter/daml-azure-deployment-templates/main"

# login
az login --identity --username "${managedIdentity}"

# get credentials for kubectl used for data plane operations
az aks install-cli
az aks get-credentials --name "${aksClusterName}" --resource-group "${resourceGroupName}"

# replicate images from customer Digital Asset repos
az acr import --name "${acrName}" --source "digitalasset-${company}-docker.jfrog.io/canton-enterprise:${version}" --username "${username}" --password "${password}"
az acr import --name "${acrName}" --source "digitalasset-${company}-docker.jfrog.io/http-json:${version}"         --username "${username}" --password "${password}"
az acr import --name "${acrName}" --source "digitalasset-${company}-docker.jfrog.io/trigger-service:${version}"   --username "${username}" --password "${password}"
az acr import --name "${acrName}" --source "digitalasset-${company}-docker.jfrog.io/oauth2-middleware:${version}" --username "${username}" --password "${password}"

# ensure the preview bits can be used with prompt in UI
az config set extension.use_dynamic_install=yes_without_prompt

# install the psql client
apk --no-cache add postgresql-client

# create database objects
wget -O postgresql.sql "${artifactsBaseUrl}/scripts/postgresql.sql"

# update tokens in script with real values
# shellcheck disable=SC2002
dbPass=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
sed -i "s/DB_PASS/${dbPass}/g" postgresql.sql
sed -i "s/DB_ADMIN/${administratorLogin}/g" postgresql.sql

psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=postgres user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -a -f "postgresql.sql"

# create resources in k8s
az aks command invoke --resource-group ${resourceGroupName} --name ${aksClusterName} --command "kubectl create namespace canton"
az aks command invoke --resource-group ${resourceGroupName} --name ${aksClusterName} --command "kubectl -n canton create secret generic postgresql-roles --from-literal=domain=${dbPass} --from-literal=json=${dbPass} --from-literal=mediator=${dbPass} --from-literal=participant1=${dbPass} --from-literal=participant2=${dbPass} --from-literal=sequencer=${dbPass} --from-literal=trigger=${dbPass}"

# allow to pull from ACR namespace wide
acrPassword=$(az acr credential show --resource-group "${resourceGroupName}" --name "${acrName}" --query passwords[0].value --output tsv)
k8s_secret_name="${acrName}.azurecr.io"
az aks command invoke --resource-group ${resourceGroupName} --name ${aksClusterName} --command "kubectl -n canton create secret docker-registry ${k8s_secret_name} --docker-server=${k8s_secret_name} --docker-username=${acrName} --docker-password=${acrPassword}"
az aks command invoke --resource-group ${resourceGroupName} --name ${aksClusterName} --command "kubectl -n canton patch serviceaccount default -p {\"imagePullSecrets\": [{\"name\": \"${k8s_secret_name}\"}]}"

# install helm
wget https://get.helm.sh/helm-v3.11.2-linux-amd64.tar.gz
tar -zxvf helm-v3.11.2-linux-amd64.tar.gz
cp linux-amd64/helm /usr/local/bin

# install helmfile
wget https://github.com/helmfile/helmfile/releases/download/v0.154.0/helmfile_0.154.0_linux_amd64.tar.gz
tar -xvf helmfile_0.154.0_linux_amd64.tar.gz -C /usr/local/bin --totals helmfile
chmod 755 /usr/local/bin/helmfile

# install plugin for helm replace
helm plugin install https://github.com/databus23/helm-diff
helm plugin install https://github.com/infog/helm-replace-values-env

# pull the helm charts
# helm repo add digital-asset https://digital-asset.github.io/daml-helm-charts