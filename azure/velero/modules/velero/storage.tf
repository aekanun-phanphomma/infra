###############################################################################
# storage.tf — the Velero BackupStorageLocation target.
#
# A dedicated Storage Account + private blob container. Versioning and soft
# delete are on so a deleted or overwritten backup can be recovered. We do NOT
# add a blob lifecycle policy: Velero expires backups itself via each backup's
# TTL, and an out-of-band lifecycle rule could delete blobs Velero still tracks.
###############################################################################

resource "azurerm_storage_account" "this" {
  name                = var.storage_account_name
  resource_group_name = var.resource_group_name
  location            = var.location

  account_kind             = "StorageV2"
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_replication_type

  # Security posture: TLS 1.2+, HTTPS only, no public blobs, key-less by default.
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = var.shared_access_key_enabled
  public_network_access_enabled   = var.public_network_access_enabled

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = var.blob_soft_delete_days
    }

    container_delete_retention_policy {
      days = var.container_soft_delete_days
    }
  }

  dynamic "network_rules" {
    for_each = var.network_rules == null ? [] : [var.network_rules]
    content {
      default_action             = network_rules.value.default_action
      bypass                     = network_rules.value.bypass
      ip_rules                   = network_rules.value.ip_rules
      virtual_network_subnet_ids = network_rules.value.virtual_network_subnet_ids
    }
  }

  tags = var.tags
}

# Management-plane container creation (storage_account_id) so Terraform does not
# need a shared key — consistent with shared_access_key_enabled = false.
resource "azurerm_storage_container" "this" {
  name                  = var.container_name
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}
