output "vm_name" {
  value = azurerm_linux_virtual_machine.rancher_vm.name
}

output "public_ip_address" {
  value = azurerm_public_ip.rancher_pip.ip_address
}

output "private_ip_address" {
  value = azurerm_network_interface.rancher_nic.private_ip_address
}

output "rancher_url" {
  value = "https://${azurerm_network_interface.rancher_nic.private_ip_address}"
}
