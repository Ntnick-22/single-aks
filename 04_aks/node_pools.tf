# DB pool — only database workloads land here.
# The taint "role=db:NoSchedule" rejects any pod that does not declare
# a matching toleration, keeping this pool exclusively for DB pods.
# Uncomment when DB workload separation is needed.
#
# resource "azurerm_kubernetes_cluster_node_pool" "db_pool" {
#   name                  = "dbpool"
#   kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
#   vm_size               = "Standard_D2s_v3"
#   node_count            = 1
#   vnet_subnet_id        = azurerm_subnet.aks_subnet.id
#
#   node_labels = {
#     role = "db"
#   }
#
#   node_taints = ["role=db:NoSchedule"]
#
#   upgrade_settings {
#     max_surge = "10%"
#   }
# }

# Prod pool — dedicated nodes for production workloads.
# Uncomment when prod workload separation is needed.
#
# resource "azurerm_kubernetes_cluster_node_pool" "prod_pool" {
#   name                  = "prodpool"
#   kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
#   vm_size               = "Standard_D2s_v3"
#   node_count            = 1
#   vnet_subnet_id        = azurerm_subnet.aks_subnet.id
#
#   node_labels = {
#     role = "prod"
#   }
#
#   upgrade_settings {
#     max_surge = "10%"
#   }
# }
