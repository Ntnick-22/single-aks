terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "learn-tf-remote-state"
    storage_account_name = "learntfremotestate01"
    container_name       = "tfstate"
    key                  = "02_vm/terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}