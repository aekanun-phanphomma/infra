locals {
  subscription_id = data.azurerm_client_config.current.subscription_id

  # The AKS node resource group (MC_*) holds the cluster's managed disks. Velero
  # needs snapshot rights there; construct its resource ID from the name AKS
  # reports. Any extra disk RGs are appended.
  node_resource_group_id = "/subscriptions/${local.subscription_id}/resourceGroups/${data.azurerm_kubernetes_cluster.this.node_resource_group}"

  snapshot_scope_ids = concat([local.node_resource_group_id], var.extra_snapshot_scope_ids)
}
