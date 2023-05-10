#!/bin/bash

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
akvName="${12}"

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
wget -O postgresql.sql https://raw.githubusercontent.com/caleteeter/daml-azure-deployment-templates/main/assets/postgresql.sql

# update tokens in script with real values
dbPass=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
sed -i "s/DB_PASS/${dbPass}/g" postgresql.sql
sed -i "s/DB_ADMIN/${administratorLogin}/g" postgresql.sql

psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=postgres user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -a -f "postgresql.sql"

# create resources in k8s
kubectl create namespace canton
kubectl -n canton create secret generic postgresql-roles --from-literal=domain=${dbPass} --from-literal=json=${dbPass} --from-literal=mediator=${dbPass} --from-literal=participant1=${dbPass} --from-literal=participant2=${dbPass} --from-literal=sequencer=${dbPass} --from-literal=trigger=${dbPass}

# allow to pull from ACR namespace wide
acrPassword=$(az acr credential show --resource-group "${resourceGroupName}" --name "${acrName}" --query passwords[0].value --output tsv)
k8s_secret_name="${acrName}.azurecr.io"
kubectl -n canton create secret docker-registry "${k8s_secret_name}" --docker-server="${k8s_secret_name}" --docker-username="${acrName}" --docker-password="${acrPassword}"
kubectl -n canton patch serviceaccount default -p "{\"imagePullSecrets\": [{\"name\": \"${k8s_secret_name}\"}]}"

# install helm
wget https://get.helm.sh/helm-v3.11.2-linux-amd64.tar.gz
tar -zxvf helm-v3.11.2-linux-amd64.tar.gz
cp linux-amd64/helm /usr/local/bin

# install helmfile
wget https://github.com/helmfile/helmfile/releases/download/v0.151.0/helmfile_0.151.0_linux_amd64.tar.gz
tar -zxvf helmfile_0.151.0_linux_amd64.tar.gz
cp helmfile /usr/local/bin

# install plugin for helm replace
helm plugin install https://github.com/databus23/helm-diff
helm plugin install https://github.com/infog/helm-replace-values-env

# pull the helm charts
helm repo add canton https://digital-asset.github.io/daml-helm-charts
helm pull canton/canton-domain
helm pull canton/canton-participant
helm pull canton/daml-http-json
helm pull canton/daml-trigger

# extract helm charts
mkdir charts
tar -zxvf canton-domain-0.0.8.tgz -C charts/
tar -zxvf canton-participant-0.0.8.tgz -C charts/
tar -zxvf daml-trigger-0.0.8.tgz -C charts/
tar -zxvf daml-http-json-0.0.8.tgz -C charts/

# download helm chart values
mkdir values
wget -O values/azure.yaml https://raw.githubusercontent.com/caleteeter/daml-azure-deployment-templates/main/values/azure.yaml
wget -O values/common.yaml https://raw.githubusercontent.com/caleteeter/daml-azure-deployment-templates/main/values/common.yaml
wget -O values/domain.yaml https://raw.githubusercontent.com/caleteeter/daml-azure-deployment-templates/main/values/domain.yaml
wget -O values/http-json.yaml https://raw.githubusercontent.com/caleteeter/daml-azure-deployment-templates/main/values/http-json.yaml
wget -O values/navigator.yaml https://raw.githubusercontent.com/caleteeter/daml-azure-deployment-templates/main/values/navigator.yaml
wget -O values/participant1.yaml https://raw.githubusercontent.com/caleteeter/daml-azure-deployment-templates/main/values/participant1.yaml
wget -O values/participant2.yaml https://raw.githubusercontent.com/caleteeter/daml-azure-deployment-templates/main/values/participant2.yaml
wget -O values/storage.yaml https://raw.githubusercontent.com/caleteeter/daml-azure-deployment-templates/main/values/storage.yaml
wget -O values/trigger.yaml https://raw.githubusercontent.com/caleteeter/daml-azure-deployment-templates/main/values/trigger.yaml
wget -O environments.yaml https://raw.githubusercontent.com/caleteeter/daml-azure-deployment-templates/main/environments.yaml
wget -O helmDefaults.yaml https://raw.githubusercontent.com/caleteeter/daml-azure-deployment-templates/main/helmDefaults.yaml
wget -O helmfile.yaml https://raw.githubusercontent.com/caleteeter/daml-azure-deployment-templates/main/helmfile.yaml

# patch dynamic values for helm
export REGISTRY=${acrName}.azurecr.io
export HOST=${serverName}.postgres.database.azure.com
helm replace-values-env -f values/azure.yaml -u
helm replace-values-env -f values/storage.yaml -u

# deployment
helmfile -f helmfile.yaml -l 'default=true' apply --skip-deps 
