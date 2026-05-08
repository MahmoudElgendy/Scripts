function Create-ACR {
    $RESOURCE_GROUP = "shopping-rg"
    $LOCATION = "centralus"



    $ACR_NAME = "shoppingacr2026"


    # Create Resource Group
    az group create --name $RESOURCE_GROUP --location $LOCATION

    # Create ACR
    az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic --location $LOCATION
    az acr login --name $ACR_NAME
}

function Delete-RGS {
    az group list --query "[].name" -o tsv | ForEach-Object {
        Write-Host "Deleting Resource Group: $_" -ForegroundColor Red
        az group delete --name $_ --yes --no-wait
    }

}