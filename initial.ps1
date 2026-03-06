$RESOURCE_GROUP="school-rg"
$LOCATION="centralus"

$SQL_SERVER="school-sql-server-2026"
$SQL_DB="SchoolDb"
$SQL_ADMIN="sqladmin"
$SQL_PASSWORD="StrongPassword123!"

$ACR_NAME="schoolacr2026"
$IMAGE_NAME="schoolapi"
$IMAGE_TAG="1.0"

$APP_SERVICE_PLAN="school-plan"
$WEB_APP_NAME="gendi-school-api"
$KEYVAULT_NAME="school-kv-2026"

# Create Resource Group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create ACR
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic --location $LOCATION
az acr login --name $ACR_NAME

# Push Image
docker tag $IMAGE_NAME "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"
docker push "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"

# Create SQL Server
az sql server create --resource-group $RESOURCE_GROUP --name $SQL_SERVER --location $LOCATION --admin-user $SQL_ADMIN --admin-password $SQL_PASSWORD

# Firewall Rules
az sql server firewall-rule create --resource-group $RESOURCE_GROUP --name AllowAzureServices --server $SQL_SERVER --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0

# Create Database
az sql db create --resource-group $RESOURCE_GROUP --name $SQL_DB --server $SQL_SERVER --service-objective Basic

# Create Linux App Service Plan
az appservice plan create --resource-group $RESOURCE_GROUP --name $APP_SERVICE_PLAN --location $LOCATION --sku B1 --is-linux

# Create Web App (no image here to avoid double-config)
az webapp create --resource-group $RESOURCE_GROUP --plan $APP_SERVICE_PLAN  --name $WEB_APP_NAME --deployment-container-image-name "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"

# Enable Managed Identity
$PRINCIPAL_ID = az webapp identity assign --resource-group $RESOURCE_GROUP --name $WEB_APP_NAME --query principalId -o tsv

# Get ACR ID
$ACR_ID = az acr show --resource-group $RESOURCE_GROUP --name $ACR_NAME --query id -o tsv

# Assign AcrPull role (reliable form)
az role assignment create --assignee-object-id $PRINCIPAL_ID --assignee-principal-type ServicePrincipal --scope $ACR_ID --role AcrPull


# Create Key Vault
az keyvault create --name $KEYVAULT_NAME --resource-group $RESOURCE_GROUP --location $LOCATION --sku standard





# Give current user access to Key Vault (for demo purposes, not recommended for production)
$KV_SCOPE=$(az keyvault show -g $RESOURCE_GROUP -n $KEYVAULT_NAME --query id -o tsv)
$ME_OID=$(az ad signed-in-user show --query id -o tsv)

az role assignment create --assignee-object-id $ME_OID --assignee-principal-type User --role "Key Vault Administrator" --scope $KV_SCOPE

# give web app's managed identity access to Key Vault secrets
$WEBAPP_ID=$(az webapp identity show -g $RESOURCE_GROUP -n $WEB_APP_NAME --query principalId -o tsv)
$KV_ID=$(az keyvault show -g $RESOURCE_GROUP -n $KEYVAULT_NAME --query id -o tsv)

az role assignment create --assignee-object-id $WEBAPP_ID --assignee-principal-type ServicePrincipal --role "Key Vault Secrets User" --scope $KV_ID










$SQL_CONNECTION_STRING="Server=tcp:$SQL_SERVER.database.windows.net,1433;Database=$SQL_DB;User Id=$SQL_ADMIN;Password=$SQL_PASSWORD;Encrypt=True;TrustServerCertificate=False;"
az keyvault secret set --vault-name $KEYVAULT_NAME --name "SqlConnectionString" --value "$SQL_CONNECTION_STRING"






# Enable Managed Identity for ACR
# az webapp config container set --resource-group $RESOURCE_GROUP --name $WEB_APP_NAME --docker-custom-image-name "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}" --docker-registry-server-url "https://${ACR_NAME}.azurecr.io" --enable-app-service-storage false
az webapp update --resource-group $RESOURCE_GROUP --name $WEB_APP_NAME --set siteConfig.acrUseManagedIdentityCreds=true



az webapp config appsettings set --resource-group $RESOURCE_GROUP --name $WEB_APP_NAME --settings $SQL_CONNECTION_STRING

# Restart
az webapp restart --resource-group $RESOURCE_GROUP --name $WEB_APP_NAME

####
#$MY_IP=(Invoke-RestMethod -Uri "https://api.ipify.org")
#az sql server firewall-rule create --resource-group $RESOURCE_GROUP --name AllowMyIP --server $SQL_SERVER --start-ip-address $MY_IP --end-ip-address $MY_IP


## some times you will need to repeate the below steps to make it work, if you get 401 error when web app tries to pull image from ACR, then run below commands again to assign AcrPull role to the web app's managed identity
# $PRINCIPAL_ID=$(az webapp identity show --resource-group $RESOURCE_GROUP --name $WEB_APP_NAME --query principalId -o tsv)
# $ACR_ID=$(az acr show --resource-group $RESOURCE_GROUP --name $ACR_NAME --query id -o tsv)
# az role assignment create --assignee $PRINCIPAL_ID --scope $ACR_ID --role AcrPull