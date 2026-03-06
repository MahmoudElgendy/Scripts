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

# Create ACR
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic --location $LOCATION
az acr login --name $ACR_NAME

# Push Image
docker tag $IMAGE_NAME "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"
docker push "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"

# Create Linux App Service Plan
az appservice plan create --resource-group $RESOURCE_GROUP --name $APP_SERVICE_PLAN --location $LOCATION --sku B1 --is-linux

# Create Web App 
az webapp create --resource-group $RESOURCE_GROUP --plan $APP_SERVICE_PLAN  --name $WEB_APP_NAME --container-image-name "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"

# Enable Managed Identity
$PRINCIPAL_ID = az webapp identity assign --resource-group $RESOURCE_GROUP --name $WEB_APP_NAME --query principalId -o tsv

# Get ACR ID
$ACR_ID = az acr show --resource-group $RESOURCE_GROUP --name $ACR_NAME --query id -o tsv

# Assign AcrPull role (reliable form)
az role assignment create --assignee-object-id $PRINCIPAL_ID --assignee-principal-type ServicePrincipal --scope $ACR_ID --role AcrPull

# Create SQL Server
az sql server create --resource-group $RESOURCE_GROUP --name $SQL_SERVER --location $LOCATION --admin-user $SQL_ADMIN --admin-password $SQL_PASSWORD

# Firewall Rules
az sql server firewall-rule create --resource-group $RESOURCE_GROUP --name AllowAzureServices --server $SQL_SERVER --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0

# Create Database
az sql db create --resource-group $RESOURCE_GROUP --name $SQL_DB --server $SQL_SERVER --service-objective Basic

# Restart
az webapp restart --resource-group $RESOURCE_GROUP --name $WEB_APP_NAME

## don't forget to enable managed identity for the web app and assign AcrPull role to it, otherwise the web app won't be able to pull the image from ACR and will keep crashing with 401 error, you can run below commands to do that if you missed it in the script