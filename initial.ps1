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

# Create Resource Group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create SQL Server
az sql server create --resource-group $RESOURCE_GROUP --name $SQL_SERVER --location $LOCATION --admin-user $SQL_ADMIN --admin-password $SQL_PASSWORD

# Firewall Rules
az sql server firewall-rule create --resource-group $RESOURCE_GROUP --name AllowAzureServices --server $SQL_SERVER --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0

# Create Database
az sql db create --resource-group $RESOURCE_GROUP --name $SQL_DB --server $SQL_SERVER --service-objective Basic

# Create ACR
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic --location $LOCATION
az acr login --name $ACR_NAME

# Push Image
docker tag $IMAGE_NAME "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"
docker push "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"

# Create Linux App Service Plan
az appservice plan create --resource-group $RESOURCE_GROUP --name $APP_SERVICE_PLAN --location $LOCATION --sku B1 --is-linux

# Create Web App
az webapp create --resource-group $RESOURCE_GROUP --name $WEB_APP_NAME --plan $APP_SERVICE_PLAN --deployment-container-image-name "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"

# Enable Managed Identity
$PRINCIPAL_ID=$(az webapp identity assign --resource-group $RESOURCE_GROUP --name $WEB_APP_NAME --query principalId -o tsv)

# Get ACR ID
$ACR_ID=$(az acr show --resource-group $RESOURCE_GROUP --name $ACR_NAME --query id -o tsv)

# Assign AcrPull Role
az role assignment create --assignee $PRINCIPAL_ID --scope $ACR_ID --role AcrPull

# Configure Container
az webapp config container set   --resource-group $RESOURCE_GROUP   --name $WEB_APP_NAME   --docker-custom-image-name "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"   --docker-registry-server-url "https://${ACR_NAME}.azurecr.io"

# Enable Managed Identity for ACR
# az webapp config container set --resource-group $RESOURCE_GROUP --name $WEB_APP_NAME --docker-custom-image-name "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}" --docker-registry-server-url "https://${ACR_NAME}.azurecr.io" --enable-app-service-storage false
az webapp update --resource-group $RESOURCE_GROUP --name $WEB_APP_NAME --set siteConfig.acrUseManagedIdentityCreds=true

# Set Connection String
az webapp config connection-string set --resource-group $RESOURCE_GROUP --name $WEB_APP_NAME --settings "DefaultConnection=Server=tcp:$SQL_SERVER.database.windows.net,1433;Database=$SQL_DB;User Id=$SQL_ADMIN;Password=$SQL_PASSWORD;Encrypt=True;" --connection-string-type SQLAzure

# Restart
az webapp restart --resource-group $RESOURCE_GROUP --name $WEB_APP_NAME

####
#$MY_IP=(Invoke-RestMethod -Uri "https://api.ipify.org")
#az sql server firewall-rule create --resource-group $RESOURCE_GROUP --name AllowMyIP --server $SQL_SERVER --start-ip-address $MY_IP --end-ip-address $MY_IP


## some times you will need to repeate the below steps to make it work, if you get 401 error when web app tries to pull image from ACR, then run below commands again to assign AcrPull role to the web app's managed identity
# $PRINCIPAL_ID=$(az webapp identity show --resource-group $RESOURCE_GROUP --name $WEB_APP_NAME --query principalId -o tsv)
# $ACR_ID=$(az acr show --resource-group $RESOURCE_GROUP --name $ACR_NAME --query id -o tsv)
# az role assignment create --assignee $PRINCIPAL_ID --scope $ACR_ID --role AcrPull