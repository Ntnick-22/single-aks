terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "aks-k8-rg"
    storage_account_name = "aksk8state"
    container_name       = "tfstate"
    key                  = "00_rg/terraform.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}
}