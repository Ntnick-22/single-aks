resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  location            = data.terraform_remote_state.rg.outputs.location
  resource_group_name = data.terraform_remote_state.rg.outputs.resource_group_name
  address_space       = ["10.0.0.0/16"]
}
