data "terraform_remote_state" "rg" {
  backend = "azurerm"

  config = {
    resource_group_name  = "aks-k8-rg"
    storage_account_name = "aksk8state"
    container_name       = "tfstate"
    key                  = "00_rg/terraform.tfstate"
    use_azuread_auth     = true
  }
}