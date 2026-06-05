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
    name                       = "Allow-OpenVPN"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "1194"
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
  size                = "Standard_B2s"
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

  custom_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y openvpn easy-rsa

    echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
    sysctl -p

    make-cadir /etc/openvpn/easy-rsa
    cd /etc/openvpn/easy-rsa

    ./easyrsa init-pki
    echo "DevOps-CA" | ./easyrsa build-ca nopass
    ./easyrsa gen-dh
    ./easyrsa build-server-full server nopass
    ./easyrsa build-client-full client1 nopass

    cp pki/ca.crt /etc/openvpn/
    cp pki/issued/server.crt /etc/openvpn/
    cp pki/private/server.key /etc/openvpn/
    cp pki/dh.pem /etc/openvpn/

    openvpn --genkey secret /etc/openvpn/ta.key

    cat > /etc/openvpn/server.conf <<OVPN
    port 1194
    proto udp
    dev tun
    ca ca.crt
    cert server.crt
    key server.key
    dh dh.pem
    tls-auth ta.key 0
    server 10.8.0.0 255.255.255.0
    push "route 10.0.0.0 255.255.0.0"
    push "route 10.1.0.0 255.255.0.0"
    keepalive 10 120
    cipher AES-256-CBC
    user nobody
    group nogroup
    persist-key
    persist-tun
    status /var/log/openvpn/openvpn-status.log
    log-append /var/log/openvpn/openvpn.log
    verb 3
    OVPN

    mkdir -p /var/log/openvpn
    systemctl enable openvpn@server
    systemctl start openvpn@server
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
