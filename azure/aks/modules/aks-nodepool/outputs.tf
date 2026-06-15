locals {
  node_pool = var.ignore_node_count_changes ? one(azurerm_kubernetes_cluster_node_pool.managed) : one(azurerm_kubernetes_cluster_node_pool.fixed)
}

output "id" {
  description = "Resource ID of the node pool."
  value       = local.node_pool.id
}

output "name" {
  description = "Name of the node pool."
  value       = local.node_pool.name
}

output "mode" {
  description = "Mode of the node pool (System or User)."
  value       = local.node_pool.mode
}
