###############################################################################
# rbac.tf — least-privilege role assignments for the Velero identity.
#
#   * Storage Blob Data Contributor on the backup account — read/write backups.
#   * snapshot_role (default Contributor) on each snapshot scope — create and
#     delete managed-disk snapshots when backing up PVCs/PVs and disks. Scope
#     these to the AKS node resource group(s) (MC_*) where the disks live, not
#     the whole subscription.
###############################################################################

resource "azurerm_role_assignment" "blob" {
  count = var.assign_blob_role ? 1 : 0

  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.velero.principal_id
}

resource "azurerm_role_assignment" "snapshot" {
  for_each = toset(var.snapshot_scope_ids)

  scope                = each.value
  role_definition_name = var.snapshot_role
  principal_id         = azurerm_user_assigned_identity.velero.principal_id
}
