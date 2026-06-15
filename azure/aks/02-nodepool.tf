###############################################################################
# 02-nodepool.tf — user (workload) node pool(s) attached to the cluster from
# 01-cluster.tf, via the aks-nodepool module. node_count drift is ignored so
# the cluster autoscaler owns the size.
###############################################################################

module "aks_nodepool_user" {
  source = "./modules/aks-nodepool"

  kubernetes_cluster_id = module.aks_cluster.id

  name                 = "user"
  mode                 = "User"
  vm_size              = var.user_node_vm_size
  orchestrator_version = var.kubernetes_version

  vnet_subnet_id = local.user_subnet_id
  zones          = var.user_node_zones

  auto_scaling_enabled      = true
  min_count                 = var.user_node_min_count
  max_count                 = var.user_node_max_count
  node_count                = var.user_node_min_count
  ignore_node_count_changes = true

  max_pods                = 110
  os_type                 = "Linux"
  os_sku                  = "AzureLinux"
  os_disk_size_gb         = 256
  os_disk_type            = "Ephemeral"
  host_encryption_enabled = true

  node_labels = { "pool" = "user" }

  upgrade_settings = {
    max_surge                = "33%"
    drain_timeout_in_minutes = 30
  }

  tags = var.tags
}
