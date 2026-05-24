# Dedicated subnet for AKS nodes.
# Lives in the existing VNet from 01_networking.
# /24 gives 251 usable IPs — enough for node IPs with kubenet.
resource "azurerm_subnet" "aks_subnet" {
  name                 = "aks-subnet"
  resource_group_name  = data.terraform_remote_state.rg.outputs.resource_group_name
  virtual_network_name = data.terraform_remote_state.networking.outputs.vnet_name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = data.terraform_remote_state.rg.outputs.resource_group_name
  dns_prefix          = var.dns_prefix

  # The default node pool runs Kubernetes system components (coredns, kube-proxy).
  # It must stay in the cluster resource — cannot be a separate node pool resource.
  default_node_pool {
    name           = "default"
    node_count     = 1
    vm_size        = "Standard_D2s_v3"
    vnet_subnet_id = azurerm_subnet.aks_subnet.id

    upgrade_settings {
      max_surge = "10%"
    }
  }

  # SystemAssigned = Azure creates a managed identity for this cluster automatically.
  # No service principal credentials to rotate manually.
  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "kubenet"
    service_cidr   = "10.96.0.0/16"
    dns_service_ip = "10.96.0.10"
  }
}
