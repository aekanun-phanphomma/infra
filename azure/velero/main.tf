###############################################################################
# main.tf — discover the target cluster, create the Velero resource group, and
# hand everything to the velero module which provisions the Azure resources and
# installs Velero via Helm.
###############################################################################

data "azurerm_client_config" "current" {}

# Read the existing cluster to obtain the OIDC issuer (for workload-identity
# federation) and the node resource group (where disks/snapshots live).
data "azurerm_kubernetes_cluster" "this" {
  name                = var.aks_cluster_name
  resource_group_name = var.aks_resource_group_name
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

module "velero" {
  source = "./modules/velero"

  name_prefix         = "velero"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subscription_id     = local.subscription_id
  tags                = var.tags

  # Backup storage
  storage_account_name          = var.storage_account_name
  container_name                = var.container_name
  storage_replication_type      = var.storage_replication_type
  shared_access_key_enabled     = var.shared_access_key_enabled
  public_network_access_enabled = var.public_network_access_enabled
  network_rules                 = var.network_rules

  # Workload identity federation against the existing cluster
  oidc_issuer_url      = data.azurerm_kubernetes_cluster.this.oidc_issuer_url
  namespace            = var.namespace
  service_account_name = "velero"

  # Snapshot permissions on the node RG (+ any extra disk RGs)
  snapshot_scope_ids = local.snapshot_scope_ids
  snapshot_role      = var.snapshot_role

  # Velero install
  install_velero               = var.install_velero
  helm_chart_version           = var.helm_chart_version
  velero_image_tag             = var.velero_image_tag
  azure_plugin_image           = var.azure_plugin_image
  deploy_node_agent            = var.deploy_node_agent
  default_volumes_to_fs_backup = var.default_volumes_to_fs_backup
  backup_schedules             = var.backup_schedules
}
