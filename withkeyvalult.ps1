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

# Create SQL Server
az sql server create --resource-group $RESOURCE_GROUP --name $SQL_SERVER --location $LOCATION --admin-user $SQL_ADMIN --admin-password $SQL_PASSWORD

# Allow Azure Services
az sql server firewall-rule create --resource-group $RESOURCE_GROUP --name AllowAzureServices --server $SQL_SERVER --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0

# Create Database
az sql db create --resource-group $RESOURCE_GROUP --name $SQL_DB --server $SQL_SERVER --service-objective Basic

# Create Key Vault
az keyvault create --name $KEYVAULT_NAME --resource-group $RESOURCE_GROUP --location $LOCATION --sku standard

# Build SQL Connection String
$SQL_CONNECTION_STRING="Server=tcp:$SQL_SERVER.database.windows.net,1433;Database=$SQL_DB;User Id=$SQL_ADMIN;Password=$SQL_PASSWORD;Encrypt=True;TrustServerCertificate=False;"

# Store Secret in Key Vault
az keyvault secret set --vault-name $KEYVAULT_NAME --name "SqlConnectionString" --value "$SQL_CONNECTION_STRING"

# Get Secret URI
$SECRET_URI=$(az keyvault secret show --vault-name $KEYVAULT_NAME --name SqlConnectionString --query id -o tsv)

# Create ACR
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic --location $LOCATION

az acr login --name $ACR_NAME

# Push Docker Image
docker tag $IMAGE_NAME "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"
docker push "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"

# Create Linux App Service Plan
az appservice plan create --resource-group $RESOURCE_GROUP --name $APP_SERVICE_PLAN --location $LOCATION --sku B1 --is-linux

# Create Web App
az webapp create --resource-group $RESOURCE_GROUP --name $WEB_APP_NAME --plan $APP_SERVICE_PLAN --deployment-container-image-name "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"

# Enable Managed Identity
$PRINCIPAL_ID=$(az webapp identity assign --resource-group $RESOURCE_GROUP --name $WEB_APP_NAME --query principalId -o tsv)

# Grant ACR Pull Permission
$ACR_ID=$(az acr show --resource-group $RESOURCE_GROUP --name $ACR_NAME --query id -o tsv)
az role assignment create --assignee $PRINCIPAL_ID --scope $ACR_ID --role AcrPull
az webapp update --resource-group $RESOURCE_GROUP --name $WEB_APP_NAME --set siteConfig.acrUseManagedIdentityCreds=true

# Grant Key Vault Access
az keyvault set-policy --name $KEYVAULT_NAME --object-id $PRINCIPAL_ID --secret-permissions get list

# Configure Web App to Use Key Vault Secret
az webapp config appsettings set --resource-group $RESOURCE_GROUP --name $WEB_APP_NAME --settings "ConnectionStrings__DefaultConnection=@Microsoft.KeyVault(SecretUri=$SECRET_URI)"

# Remove any previous connection-string configuration (safe cleanup)
az webapp config connection-string delete --resource-group $RESOURCE_GROUP --name $WEB_APP_NAME --setting-names DefaultConnection

# Restart Web App
az webapp restart --resource-group $RESOURCE_GROUP --name $WEB_APP_NAME