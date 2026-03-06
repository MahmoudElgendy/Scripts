# =========================
# VARIABLES
# =========================
$RESOURCE_GROUP="school-rg"
$LOCATION="centralus"

$SQL_SERVER="school-sql-server-2026"
$SQL_DB="SchoolDb"
$SQL_ADMIN="sqladmin"
$SQL_PASSWORD="StrongPassword123!"  # NOTE: for production, don't hardcode passwords

$ACR_NAME="schoolacr2026"
$IMAGE_NAME="schoolapi"             # must match your LOCAL image name
$IMAGE_TAG="1.0"

$APP_SERVICE_PLAN="school-plan"
$WEB_APP_NAME="gendi-school-api"

$KEYVAULT_NAME="school-kv-2026"

$MY_IP=(Invoke-RestMethod -Uri "https://api.ipify.org").ToString().Trim()

# ASP.NET Core / App Service container port (make sure your app listens on this)
$CONTAINER_PORT=8080

# Connection string key name used by your app:
# - If your code uses GetConnectionString("DefaultConnection") => keep DefaultConnection
# - If your code uses GetConnectionString("Default") => change to Default
$CONN_NAME="DefaultConnection"


# =========================
# CREATE RESOURCE GROUP
# =========================
az group create --name $RESOURCE_GROUP --location $LOCATION


# =========================
# CREATE SQL SERVER + DB
# =========================
az sql server create --resource-group $RESOURCE_GROUP --name $SQL_SERVER --location $LOCATION --admin-user $SQL_ADMIN --admin-password $SQL_PASSWORD

az sql server firewall-rule create --resource-group $RESOURCE_GROUP --server $SQL_SERVER --name AllowMyIP --start-ip-address $MY_IP --end-ip-address $MY_IP

az sql server firewall-rule create --resource-group $RESOURCE_GROUP --server $SQL_SERVER --name AllowAzureServices --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0

az sql db create --resource-group $RESOURCE_GROUP --server $SQL_SERVER --name $SQL_DB --service-objective S0


# =========================
# CREATE KEY VAULT (RBAC by default)
# =========================
az keyvault create --name $KEYVAULT_NAME --resource-group $RESOURCE_GROUP --location $LOCATION


# =========================
# CREATE ACR + PUSH IMAGE
# =========================
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic --admin-enabled false

az acr login --name $ACR_NAME

# Validate local image exists
docker image inspect $IMAGE_NAME | Out-Null

docker tag $IMAGE_NAME "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"
docker push "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"


# =========================
# CREATE APP SERVICE PLAN + WEB APP (CONTAINER)
# =========================
az appservice plan create --name $APP_SERVICE_PLAN --resource-group $RESOURCE_GROUP --sku B1 --is-linux

az webapp create --resource-group $RESOURCE_GROUP --plan $APP_SERVICE_PLAN --name $WEB_APP_NAME --deployment-container-image-name "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"


# =========================
# ENABLE MANAGED IDENTITY + ALLOW ACR PULL
# =========================
az webapp identity assign --name $WEB_APP_NAME --resource-group $RESOURCE_GROUP

$WEBAPP_IDENTITY=$(az webapp identity show --name $WEB_APP_NAME --resource-group $RESOURCE_GROUP --query principalId -o tsv)
$ACR_ID=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query id -o tsv)

az role assignment create --assignee $WEBAPP_IDENTITY --role AcrPull --scope $ACR_ID


# =========================
# FORCE PORT SETTINGS FOR CONTAINER
# =========================
az webapp config appsettings set -g $RESOURCE_GROUP -n $WEB_APP_NAME --settings "WEBSITES_PORT=$CONTAINER_PORT" "ASPNETCORE_URLS=http://0.0.0.0:$CONTAINER_PORT"


# =========================
# CREATE CONNECTION STRING + STORE IN KEY VAULT
# =========================
$SQL_CONNECTION_STRING="Server=tcp:${SQL_SERVER}.database.windows.net,1433;Initial Catalog=${SQL_DB};User ID=${SQL_ADMIN};Password=${SQL_PASSWORD};Encrypt=True"

# Give YOUR USER Key Vault admin (RBAC) so you can set secrets
$KV_SCOPE=$(az keyvault show -g $RESOURCE_GROUP -n $KEYVAULT_NAME --query id -o tsv)
$ME_OID=$(az ad signed-in-user show --query id -o tsv)

az role assignment create --assignee-object-id $ME_OID --assignee-principal-type User --role "Key Vault Administrator" --scope $KV_SCOPE

# RBAC propagation retry for secret set
for($i=1; $i -le 18; $i++){
  try {
    az keyvault secret set --vault-name $KEYVAULT_NAME --name SqlConnectionString --value "$SQL_CONNECTION_STRING" | Out-Null
    Write-Host "Key Vault secret set successfully."
    break
  } catch {
    Write-Host "Waiting for RBAC propagation... attempt $i/18"
    Start-Sleep -Seconds 10
  }
}
if ($i -gt 18) { throw "Failed to set Key Vault secret after retries. Check RBAC permissions." }


# =========================
# GIVE WEB APP ACCESS TO KEY VAULT SECRETS
# =========================
$KV_ID=$(az keyvault show --name $KEYVAULT_NAME --resource-group $RESOURCE_GROUP --query id -o tsv)
az role assignment create --assignee $WEBAPP_IDENTITY --role "Key Vault Secrets User" --scope $KV_ID


# =========================
# INJECT KEY VAULT SECRET INTO WEB APP SETTINGS
# =========================
$SECRET_URI=$(az keyvault secret show --vault-name $KEYVAULT_NAME --name SqlConnectionString --query properties.secretUriWithVersion -o tsv)

az webapp config appsettings set -g $RESOURCE_GROUP -n $WEB_APP_NAME --settings "ConnectionStrings__${CONN_NAME}=@Microsoft.KeyVault(SecretUri=$SECRET_URI)"


# =========================
# RESTART WEB APP
# =========================
az webapp restart -g $RESOURCE_GROUP -n $WEB_APP_NAME

Write-Host "Done. Web App: $WEB_APP_NAME  |  Image: ${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"