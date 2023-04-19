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

# create roles
psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=postgres user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "CREATE ROLE domain WITH PASSWORD 'umn2uAR3byW4uDERUWD4s19RebC6eb2_pr6eCmfa' LOGIN; ALTER ROLE domain SET statement_timeout=60000; COMMENT ON ROLE domain IS 'Canton - Domain topology manager role';"
psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=postgres user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "CREATE ROLE mediator WITH PASSWORD 'eFDW5kY5y2sThMnrD14BVajGdrJQK1zpjXBs49_m' LOGIN; ALTER ROLE mediator SET statement_timeout=60000; COMMENT ON ROLE mediator IS 'Canton - Mediator role';"
psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=postgres user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "CREATE ROLE sequencer WITH PASSWORD 'mfd?f=mVDrtKwL=UjDGJXAEbkWm22Zgu5QBEz=UJ' LOGIN; ALTER ROLE sequencer SET statement_timeout=60000; COMMENT ON ROLE sequencer IS 'Canton - Sequencer role';"
psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=postgres user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "CREATE ROLE participant1 WITH PASSWORD 'EQY#QPmnUbx_eXp1HzJmK98fKcUVryLCa31xq6NR' LOGIN; ALTER ROLE participant1 SET statement_timeout=60000; COMMENT ON ROLE participant1 IS 'Canton - Participant role';"
psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=postgres user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "CREATE ROLE participant2 WITH PASSWORD 'iAZfuP27a2GRci1jWdzXPWcDJ4Y1KtHY59XvapiJ' LOGIN; ALTER ROLE participant2 SET statement_timeout=60000; COMMENT ON ROLE participant2 IS 'Canton - Participant role';"
psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=postgres user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "CREATE ROLE json WITH PASSWORD 'dvpKN3tNBV9SBZ19qNFJqWPtHzKiZXp9Vn?#i1eU' LOGIN; ALTER ROLE json SET statement_timeout=60000; COMMENT ON ROLE json IS 'Daml - HTTP JSON API service role';"
psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=postgres user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "CREATE ROLE trigger WITH PASSWORD 'h68M#M1uL4pGgwU1dXN9zN7j+KBhQprNBbA9NJHP' LOGIN; ALTER ROLE trigger SET statement_timeout=60000; COMMENT ON ROLE trigger IS 'Daml - Trigger service role';"

# create databases
psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=postgres user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "GRANT domain TO ${administratorLogin};"
psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=postgres user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "CREATE DATABASE domain OWNER domain;"
psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=postgres user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "COMMENT ON DATABASE domain IS 'Canton - Domain topology manager database'; REVOKE ALL ON DATABASE domain FROM public; GRANT CONNECT ON DATABASE domain TO domain;"
psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=domain   user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "REVOKE ALL ON schema public FROM public; ALTER SCHEMA public OWNER TO domain;"

psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=postgres user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "GRANT mediator TO ${administratorLogin};"
psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=postgres user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "CREATE DATABASE mediator OWNER mediator;"
psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=postgres user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "COMMENT ON DATABASE mediator IS 'Canton - Mediator database'; REVOKE ALL ON DATABASE mediator FROM public; GRANT CONNECT ON DATABASE mediator TO mediator;"
psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=mediator user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "REVOKE ALL ON schema public FROM public; ALTER SCHEMA public OWNER TO mediator;"

psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=postgres  user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "GRANT sequencer TO ${administratorLogin};"
psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=postgres  user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "CREATE DATABASE sequencer OWNER sequencer;"
psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=postgres  user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "COMMENT ON DATABASE sequencer IS 'Canton - Sequencer database'; REVOKE ALL ON DATABASE sequencer FROM public; GRANT CONNECT ON DATABASE sequencer TO sequencer;"
psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=sequencer user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "REVOKE ALL ON schema public FROM public; ALTER SCHEMA public OWNER TO sequencer;"

psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=postgres     user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "GRANT participant1 TO ${administratorLogin};"
psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=postgres     user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "CREATE DATABASE participant1 OWNER participant1;"
psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=postgres     user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "COMMENT ON DATABASE participant1 IS 'Canton - Participant database'; REVOKE ALL ON DATABASE participant1 FROM public; GRANT CONNECT ON DATABASE participant1 TO participant1;"
psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=participant1 user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "REVOKE ALL ON schema public FROM public; ALTER SCHEMA public OWNER TO participant1;"

psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=postgres     user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "GRANT participant2 TO ${administratorLogin};"
psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=postgres     user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "CREATE DATABASE participant2 OWNER participant2;"
psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=postgres     user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "COMMENT ON DATABASE participant2 IS 'Canton - Participant database'; REVOKE ALL ON DATABASE participant2 FROM public; GRANT CONNECT ON DATABASE participant2 TO participant2;"
psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=participant2 user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "REVOKE ALL ON schema public FROM public; ALTER SCHEMA public OWNER TO participant2;"

psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=postgres user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "GRANT json TO ${administratorLogin};"
psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=postgres user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "CREATE DATABASE json OWNER json;"
psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=postgres user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "COMMENT ON DATABASE json IS 'Daml - HTTP JSON API service database'; REVOKE ALL ON DATABASE json FROM public; GRANT CONNECT ON DATABASE json TO json;"
psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=json     user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "REVOKE ALL ON schema public FROM public; ALTER SCHEMA public OWNER TO json;"

psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=postgres user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "GRANT trigger TO ${administratorLogin};"
psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=postgres user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "CREATE DATABASE trigger OWNER trigger;"
psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=postgres user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "COMMENT ON DATABASE trigger IS 'Daml - Trigger service database'; REVOKE ALL ON DATABASE trigger FROM public; GRANT CONNECT ON DATABASE trigger TO trigger;"
psql "host=${serverName}.postgres.database.azure.com port=5432 dbname=trigger  user=${administratorLogin} password=${administratorLoginPassword} sslmode=require" -c "REVOKE ALL ON schema public FROM public; ALTER SCHEMA public OWNER TO trigger;"

# create resources in k8s
kubectl create namespace canton
kubectl -n canton create secret generic postgresql-roles \
  --from-literal=domain='umn2uAR3byW4uDERUWD4s19RebC6eb2_pr6eCmfa' \
  --from-literal=json='dvpKN3tNBV9SBZ19qNFJqWPtHzKiZXp9Vn?#i1eU' \
  --from-literal=mediator='eFDW5kY5y2sThMnrD14BVajGdrJQK1zpjXBs49_m' \
  --from-literal=participant1='EQY#QPmnUbx_eXp1HzJmK98fKcUVryLCa31xq6NR' \
  --from-literal=participant2='iAZfuP27a2GRci1jWdzXPWcDJ4Y1KtHY59XvapiJ' \
  --from-literal=sequencer='mfd?f=mVDrtKwL=UjDGJXAEbkWm22Zgu5QBEz=UJ' \
  --from-literal=trigger='h68M#M1uL4pGgwU1dXN9zN7j+KBhQprNBbA9NJHP'

# allow to pull from ACR namespace wide
acrPassword=$(az acr credential show --resource-group "${resourceGroupName}" --name "${acrName}" --query passwords[0].value --output tsv)
k8s_secret_name="${acrName}.azurecr.io"
kubectl -n canton create secret docker-registry "${k8s_secret_name}" \
  --docker-server="${k8s_secret_name}" \
  --docker-username="${acrName}" \
  --docker-password="${acrPassword}"
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
helm plugin install https://github.com/infog/helm-replace-values-env

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
