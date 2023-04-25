#!/bin/bash
set -euo pipefail

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
wget "https://raw.githubusercontent.com/caleteeter/daml-azure-deployment-templates/main/assets/postgresql.sql"

# update tokens in script with real values
dbPass=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
sed -i "s/DB_PASS/${dbPass}/g" postgresql.sql
sed -i "s/DB_ADMIN/${administratorLogin}/g" postgresql.sql

# psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=postgres user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -a -f "postgresql.sql"

# create resources in k8s
# kubectl create namespace canton
# kubectl -n canton create secret generic postgresql-roles --from-literal=domain='umn2uAR3byW4uDERUWD4s19RebC6eb2_pr6eCmfa' --from-literal=json='dvpKN3tNBV9SBZ19qNFJqWPtHzKiZXp9Vn?#i1eU' --from-literal=mediator='eFDW5kY5y2sThMnrD14BVajGdrJQK1zpjXBs49_m' --from-literal=participant1='EQY#QPmnUbx_eXp1HzJmK98fKcUVryLCa31xq6NR' --from-literal=participant2='iAZfuP27a2GRci1jWdzXPWcDJ4Y1KtHY59XvapiJ' --from-literal=sequencer='mfd?f=mVDrtKwL=UjDGJXAEbkWm22Zgu5QBEz=UJ' --from-literal=trigger='h68M#M1uL4pGgwU1dXN9zN7j+KBhQprNBbA9NJHP'

# allow to pull from ACR namespace wide
# acrPassword=$(az acr credential show --resource-group "${resourceGroupName}" --name "${acrName}" --query passwords[0].value --output tsv)
# k8s_secret_name="${acrName}.azurecr.io"
# kubectl -n canton create secret docker-registry "${k8s_secret_name}" --docker-server="${k8s_secret_name}" --docker-username="${acrName}" --docker-password="${acrPassword}"
# kubectl -n canton patch serviceaccount default -p "{\"imagePullSecrets\": [{\"name\": \"${k8s_secret_name}\"}]}"

# install helm
# wget https://get.helm.sh/helm-v3.11.2-linux-amd64.tar.gz
# tar -zxvf helm-v3.11.2-linux-amd64.tar.gz
# cp linux-amd64/helm /usr/local/bin

# install helmfile
# wget https://github.com/helmfile/helmfile/releases/download/v0.151.0/helmfile_0.151.0_linux_amd64.tar.gz
# tar -zxvf helmfile_0.151.0_linux_amd64.tar.gz
# cp helmfile /usr/local/bin

# install plugin for helm replace
# helm plugin install https://github.com/infog/helm-replace-values-env

# patch helm files
# export REPOSITORY=$acrName.azurecr.io/canton-enterprise
# helm replace-values-env -f values/aks/canton.yaml -u
# helm replace-values-env -f values/aks/participant1.yaml -u
# helm replace-values-env -f values/aks/participant2.yaml -u
# helm replace-values-env -f values/aks/canton.yaml -u

# export REPOSITORY=$acrName.azurecr.io/http-json
# helm replace-values-env -f values/aks/http-json.yaml -u

# export REPOSITORY=$acrName.azurecr.io/trigger-service
# helm replace-values-env -f values/aks/trigger.yaml -u

# export REPOSITORY=$acrName.azurecr.io/daml-sdk
# helm replace-values-env -f values/aks/navigator.yaml -u

# export HOST=${serverName}.postgres.database.azure.com
# helm replace-values-env -f values/aks/storage.yaml -u

# deployment
# helmfile -f .\helmfile.aks.yaml -l 'default=true' apply --skip-deps
