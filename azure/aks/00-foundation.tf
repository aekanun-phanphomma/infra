###############################################################################
# 00-foundation.tf — supporting resources the cluster depends on:
#   * resource group
#   * control-plane user-assigned identity
#   * Log Analytics workspace (Container Insights)
#   * Key Vault + key + Disk Encryption Set (customer-managed disk encryption)
###############################################################################

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Control-plane identity. Using a user-assigned identity lets us pre-assign the
# roles AKS needs (DNS, networking) before the cluster exists.
resource "azurerm_user_assigned_identity" "cluster" {
  name                = local.cluster_identity
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags
}

# ----------------------------------------------------------------------------
# Observability
# ----------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "this" {
  count = var.create_log_analytics_workspace ? 1 : 0

  name                = local.workspace_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# ----------------------------------------------------------------------------
# Customer-managed disk encryption: Key Vault -> Key -> Disk Encryption Set
# ----------------------------------------------------------------------------
resource "azurerm_key_vault" "des" {
  count = var.enable_disk_encryption_set ? 1 : 0

  name                        = local.key_vault_name
  resource_group_name         = azurerm_resource_group.this.name
  location                    = azurerm_resource_group.this.location
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  enabled_for_disk_encryption = true
  purge_protection_enabled    = var.key_vault_purge_protection_enabled
  soft_delete_retention_days  = 7
  rbac_authorization_enabled  = true
  tags                        = var.tags
}

# Allow the deployer (current principal) to manage keys in the RBAC vault.
resource "azurerm_role_assignment" "deployer_kv_admin" {
  count = var.enable_disk_encryption_set ? 1 : 0

  scope                = azurerm_key_vault.des[0].id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_key" "des" {
  count = var.enable_disk_encryption_set ? 1 : 0

  name         = "des-cmk"
  key_vault_id = azurerm_key_vault.des[0].id
  key_type     = "RSA"
  key_size     = 2048
  key_opts     = ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"]

  depends_on = [azurerm_role_assignment.deployer_kv_admin]
}

resource "azurerm_disk_encryption_set" "this" {
  count = var.enable_disk_encryption_set ? 1 : 0

  name                = local.des_identity_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  key_vault_key_id    = azurerm_key_vault_key.des[0].id
  tags                = var.tags

  identity {
    type = "SystemAssigned"
  }
}

# Let the Disk Encryption Set read/unwrap the CMK.
resource "azurerm_role_assignment" "des_kv_crypto" {
  count = var.enable_disk_encryption_set ? 1 : 0

  scope                = azurerm_key_vault.des[0].id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_disk_encryption_set.this[0].identity[0].principal_id
}
