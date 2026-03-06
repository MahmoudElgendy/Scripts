# =========================
# Variables
# =========================
$RESOURCE_GROUP="school-rg"
$LOCATION="centralus"

$SQL_SERVER="school-sql-server-2026"
$SQL_DB="SchoolDb"
$SQL_ADMIN="sqladmin"
$SQL_PASSWORD_PLAIN = Read-Host "Enter SQL admin password (will be visible while typing)"
if ([string]::IsNullOrWhiteSpace($SQL_PASSWORD_PLAIN)) { throw "SQL password is required." }

$ACR_NAME="schoolacr2026"
$IMAGE_NAME="schoolapi"
$IMAGE_TAG="1.0"

$APP_SERVICE_PLAN="school-plan"
$WEB_APP_NAME="gendi-school-api"
$KEYVAULT_NAME="school-kv-2026"

$LOCAL_IMAGE_TAG="latest"

# =========================
# Create Resource Group
# =========================
az group create --name $RESOURCE_GROUP --location $LOCATION | Out-Null

# =========================
# Create Azure SQL Server + DB
# =========================
az sql server create --resource-group $RESOURCE_GROUP --name $SQL_SERVER --location $LOCATION --admin-user $SQL_ADMIN --admin-password $SQL_PASSWORD_PLAIN | Out-Null

az sql server firewall-rule create --resource-group $RESOURCE_GROUP --server $SQL_SERVER --name AllowAzureServices --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0 | Out-Null

az sql db create --resource-group $RESOURCE_GROUP --server $SQL_SERVER --name $SQL_DB --service-objective Basic | Out-Null

# =========================
# Create Key Vault (RBAC mode)
# =========================
az keyvault create --name $KEYVAULT_NAME --resource-group $RESOURCE_GROUP --location $LOCATION --sku standard --enable-rbac-authorization true | Out-Null

$KV_ID = az keyvault show --name $KEYVAULT_NAME --query id -o tsv
$OID = az ad signed-in-user show --query id -o tsv

az role assignment create --assignee-object-id $OID --assignee-principal-type User --role "Key Vault Secrets Officer" --scope $KV_ID | Out-Null

# =========================
# Build SQL connection string
# =========================
$SQL_CONNECTION_STRING="Server=tcp:$SQL_SERVER.database.windows.net,1433;Database=$SQL_DB;User ID=$SQL_ADMIN;Password=$SQL_PASSWORD_PLAIN;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

az keyvault secret set --vault-name $KEYVAULT_NAME --name "SqlConnectionString" --value $SQL_CONNECTION_STRING | Out-Null

$SECRET_URI = az keyvault secret show --vault-name $KEYVAULT_NAME --name "SqlConnectionString" --query id -o tsv

# =========================
# Create ACR
# =========================
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic --location $LOCATION | Out-Null
az acr login --name $ACR_NAME | Out-Null

# =========================
# Push Image to ACR
# =========================
docker image inspect "${IMAGE_NAME}:${LOCAL_IMAGE_TAG}" *> $null
if ($LASTEXITCODE -ne 0) { throw "Local Docker image '${IMAGE_NAME}:${LOCAL_IMAGE_TAG}' not found. Build it first." }

docker tag "${IMAGE_NAME}:${LOCAL_IMAGE_TAG}" "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"
docker push "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"

# =========================
# Create Linux App Service Plan
# =========================
az appservice plan create --resource-group $RESOURCE_GROUP --name $APP_SERVICE_PLAN --location $LOCATION --sku B1 --is-linux | Out-Null

# =========================
# Create Web App
# =========================
az webapp create --resource-group $RESOURCE_GROUP --name $WEB_APP_NAME --plan $APP_SERVICE_PLAN | Out-Null

# =========================
# Enable Managed Identity
# =========================
$PRINCIPAL_ID = az webapp identity assign --resource-group $RESOURCE_GROUP --name $WEB_APP_NAME --query principalId -o tsv

# =========================
# RBAC: Allow Web App to pull from ACR
# =========================
$ACR_ID = az acr show --resource-group $RESOURCE_GROUP --name $ACR_NAME --query id -o tsv
az role assignment create --assignee $PRINCIPAL_ID --role "AcrPull" --scope $ACR_ID | Out-Null

# =========================
# RBAC: Allow Web App to read secrets from Key Vault
# =========================
az role assignment create --assignee $PRINCIPAL_ID --role "Key Vault Secrets User" --scope $KV_ID | Out-Null

# =========================
# Configure container
# =========================
az webapp config container set --resource-group $RESOURCE_GROUP --name $WEB_APP_NAME --docker-custom-image-name "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}" --docker-registry-server-url "https://${ACR_NAME}.azurecr.io" | Out-Null

az webapp update --resource-group $RESOURCE_GROUP --name $WEB_APP_NAME --set siteConfig.acrUseManagedIdentityCreds=true | Out-Null

# =========================
# Configure Key Vault reference
# =========================
az webapp config appsettings set --resource-group $RESOURCE_GROUP --name $WEB_APP_NAME --settings "ConnectionStrings__DefaultConnection=@Microsoft.KeyVault(SecretUri=$SECRET_URI)" | Out-Null

# =========================
# Restart Web App
# =========================
az webapp restart --resource-group $RESOURCE_GROUP --name $WEB_APP_NAME | Out-Null

Write-Host "DONE ✅ Web App '$WEB_APP_NAME' deployed with ACR + Key Vault (RBAC)."