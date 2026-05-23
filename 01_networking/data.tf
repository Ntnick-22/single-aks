data "terraform_remote_state" "rg" {
  backend = "azurerm"

  config = {
    resource_group_name  = "learn-tf-remote-state"
    storage_account_name = "learntfremotestate01"
    container_name       = "tfstate"
    key                  = "00_rg/terraform.tfstate"
    use_azuread_auth     = true
  }
}