output "vm_name" {
  value = azurerm_linux_virtual_machine.vm.name
}

output "public_ip_address" {
  value = azurerm_public_ip.pip.ip_address
}

output "private_ip_address" {
  value = azurerm_network_interface.nic.private_ip_address
}

output "vpn_vnet_id" {
  value = azurerm_virtual_network.vpn_vnet.id
}

output "vpn_vnet_name" {
  value = azurerm_virtual_network.vpn_vnet.name
}
