# New subnet inside the VPN VNet (10.1.0.0/16).
# VPN clients already get a route for 10.1.0.0/16 so Rancher UI is reachable
# the moment OpenVPN connects — no extra routing config needed.
resource "azurerm_subnet" "rancher_subnet" {
  name                 = "rancher-subnet"
  resource_group_name  = data.terraform_remote_state.rg.outputs.resource_group_name
  virtual_network_name = data.terraform_remote_state.vm.outputs.vpn_vnet_name
  address_prefixes     = ["10.1.2.0/24"]
}

resource "azurerm_public_ip" "rancher_pip" {
  name                = "rancher-vm-pip"
  location            = data.terraform_remote_state.rg.outputs.location
  resource_group_name = data.terraform_remote_state.rg.outputs.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "rancher_nsg" {
  name                = "rancher-vm-nsg"
  location            = data.terraform_remote_state.rg.outputs.location
  resource_group_name = data.terraform_remote_state.rg.outputs.resource_group_name

  # SSH stays VPN-gated for admin access. Ports 80/443 are gone entirely —
  # Cloudflare Tunnel is outbound-only from the VM, so the Rancher UI needs
  # zero inbound web ports open at all.
  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.8.0.0/24"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "rancher_nic" {
  name                = "rancher-vm-nic"
  location            = data.terraform_remote_state.rg.outputs.location
  resource_group_name = data.terraform_remote_state.rg.outputs.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.rancher_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.rancher_pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "rancher_nic_nsg" {
  network_interface_id      = azurerm_network_interface.rancher_nic.id
  network_security_group_id = azurerm_network_security_group.rancher_nsg.id
}

resource "azurerm_linux_virtual_machine" "rancher_vm" {
  name                = var.vm_name
  location            = data.terraform_remote_state.rg.outputs.location
  resource_group_name = data.terraform_remote_state.rg.outputs.resource_group_name
  size                = "Standard_D2s_v3"
  admin_username      = "azureuser"

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.rancher_nic.id
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

  # Boot script: installs Docker, then runs Rancher as a container.
  # Rancher binds ports 80 and 443 on the host — that's the UI.
  # --privileged is required by Rancher to manage its embedded k3s control plane.
  # --restart=unless-stopped means Rancher survives VM reboots automatically.
  custom_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y docker.io curl
    systemctl enable docker
    systemctl start docker

    sleep 10

    docker run -d --restart=unless-stopped \
      -p 80:80 -p 443:443 \
      --privileged \
      rancher/rancher:latest

    # Cloudflare Tunnel: outbound-only connector, no inbound ports needed.
    # Public hostname -> localhost:443 is configured on the Cloudflare side.
    curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o /tmp/cloudflared.deb
    dpkg -i /tmp/cloudflared.deb
    cloudflared service install ${var.cloudflare_tunnel_token}
    EOF
  )
}
