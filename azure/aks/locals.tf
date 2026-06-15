locals {
  # Resolve the user node pool subnet, falling back to the system subnet.
  user_subnet_id = coalesce(var.user_subnet_id, var.nodes_subnet_id)

  # Log Analytics workspace ID used by Container Insights, regardless of source.
  log_analytics_workspace_id = var.create_log_analytics_workspace ? azurerm_log_analytics_workspace.this[0].id : var.log_analytics_workspace_id

  # Disk Encryption Set ID wired into the cluster when CMK is enabled.
  disk_encryption_set_id = var.enable_disk_encryption_set ? azurerm_disk_encryption_set.this[0].id : null

  # Naming helpers kept short and predictable.
  name_suffix       = replace(var.cluster_name, "-", "")
  key_vault_name    = substr("kv${local.name_suffix}des", 0, 24)
  workspace_name    = "log-${var.cluster_name}"
  cluster_identity  = "id-${var.cluster_name}"
  des_identity_name = "des-${var.cluster_name}"
}
