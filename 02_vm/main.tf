resource "azurerm_virtual_network" "vpn_vnet" {
  name                = var.vpn_vnet_name
  location            = data.terraform_remote_state.rg.outputs.location
  resource_group_name = data.terraform_remote_state.rg.outputs.resource_group_name
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "vpn_subnet" {
  name                 = "vpn-subnet"
  resource_group_name  = data.terraform_remote_state.rg.outputs.resource_group_name
  virtual_network_name = azurerm_virtual_network.vpn_vnet.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_public_ip" "pip" {
  name                = "vpn-vm-pip"
  location            = data.terraform_remote_state.rg.outputs.location
  resource_group_name = data.terraform_remote_state.rg.outputs.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "nsg" {
  name                = "vpn-vm-nsg"
  location            = data.terraform_remote_state.rg.outputs.location
  resource_group_name = data.terraform_remote_state.rg.outputs.resource_group_name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-WireGuard"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "51820"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "nic" {
  name                = "vpn-vm-nic"
  location            = data.terraform_remote_state.rg.outputs.location
  resource_group_name = data.terraform_remote_state.rg.outputs.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vpn_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = var.vm_name
  location            = data.terraform_remote_state.rg.outputs.location
  resource_group_name = data.terraform_remote_state.rg.outputs.resource_group_name
  size                = "Standard_D2s_v3"
  admin_username      = "azureuser"

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  # WireGuard: each side generates its own keypair; only public keys are exchanged.
  # The server's private key never leaves this VM, and the client's private key
  # (on your laptop) never gets sent here at all — only its public key is baked
  # into this boot script as a Terraform variable.
  custom_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y wireguard

    echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
    sysctl -p

    umask 077
    wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey

    cat > /etc/wireguard/wg0.conf <<WG
    [Interface]
    Address = 10.8.0.1/24
    ListenPort = 51820
    PrivateKey = $(cat /etc/wireguard/privatekey)
    PostUp = iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
    PostDown = iptables -t nat -D POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE

    [Peer]
    PublicKey = ${var.wg_client_public_key}
    AllowedIPs = 10.8.0.2/32
    WG

    systemctl enable wg-quick@wg0
    systemctl start wg-quick@wg0
    EOF
  )
}

resource "azurerm_virtual_network_peering" "vpn_to_aks" {
  name                      = "vpn-to-aks"
  resource_group_name       = data.terraform_remote_state.rg.outputs.resource_group_name
  virtual_network_name      = azurerm_virtual_network.vpn_vnet.name
  remote_virtual_network_id = data.terraform_remote_state.networking.outputs.vnet_id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "aks_to_vpn" {
  name                      = "aks-to-vpn"
  resource_group_name       = data.terraform_remote_state.rg.outputs.resource_group_name
  virtual_network_name      = data.terraform_remote_state.networking.outputs.vnet_name
  remote_virtual_network_id = azurerm_virtual_network.vpn_vnet.id
  allow_forwarded_traffic   = true
}
