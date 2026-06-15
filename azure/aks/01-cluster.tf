###############################################################################
# 01-cluster.tf — the AKS control plane + system node pool, via the
# aks-cluster module. Private cluster, AAD RBAC, workload identity, customer-
# managed disk encryption and the Key Vault Secrets Provider are all enabled.
###############################################################################

module "aks_cluster" {
  source = "./modules/aks-cluster"

  name                = var.cluster_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  node_resource_group = "${var.resource_group_name}-nodes"
  kubernetes_version  = var.kubernetes_version
  sku_tier            = "Standard"
  tags                = var.tags

  # ----- Private cluster -----------------------------------------------------
  private_cluster_enabled = true
  private_dns_zone_id     = var.private_dns_zone_id
  dns_prefix              = var.cluster_name

  # ----- Identity ------------------------------------------------------------
  identity = {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.cluster.id]
  }

  # ----- RBAC / Entra ID -----------------------------------------------------
  role_based_access_control_enabled = true
  local_account_disabled            = true
  azure_active_directory_role_based_access_control = {
    azure_rbac_enabled     = true
    tenant_id              = data.azurerm_client_config.current.tenant_id
    admin_group_object_ids = var.admin_group_object_ids
  }

  # ----- Workload identity ---------------------------------------------------
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # ----- Governance / upgrades ----------------------------------------------
  azure_policy_enabled      = true
  automatic_upgrade_channel = "stable"
  node_os_upgrade_channel   = "NodeImage"

  # ----- Disk encryption (CMK) ----------------------------------------------
  disk_encryption_set_id = local.disk_encryption_set_id

  # ----- System node pool ----------------------------------------------------
  default_node_pool = {
    name                         = "system"
    vm_size                      = var.system_node_vm_size
    vnet_subnet_id               = var.nodes_subnet_id
    zones                        = var.system_node_zones
    auto_scaling_enabled         = true
    min_count                    = var.system_node_min_count
    max_count                    = var.system_node_max_count
    node_count                   = var.system_node_min_count
    max_pods                     = 110
    os_disk_size_gb              = 128
    os_disk_type                 = "Ephemeral"
    os_sku                       = "AzureLinux"
    only_critical_addons_enabled = true
    host_encryption_enabled      = true
    node_labels                  = { "pool" = "system" }

    upgrade_settings = {
      max_surge = "33%"
    }
  }

  # ----- Autoscaler tuning ---------------------------------------------------
  auto_scaler_profile = {
    expander                         = "least-waste"
    balance_similar_node_groups      = true
    scale_down_unneeded              = "10m"
    scale_down_utilization_threshold = "0.5"
    skip_nodes_with_system_pods      = true
    skip_nodes_with_local_storage    = false
  }

  # ----- Networking (Azure CNI overlay + Cilium dataplane) -------------------
  network_profile = {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    network_data_plane  = "cilium"
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
  }

  # ----- Add-ons -------------------------------------------------------------
  key_vault_secrets_provider = {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  storage_profile = {
    disk_driver_enabled         = true
    file_driver_enabled         = true
    blob_driver_enabled         = false
    snapshot_controller_enabled = true
  }

  workload_autoscaler_profile = {
    keda_enabled                    = true
    vertical_pod_autoscaler_enabled = false
  }

  oms_agent = {
    log_analytics_workspace_id      = local.log_analytics_workspace_id
    msi_auth_for_monitoring_enabled = true
  }

  monitor_metrics = {}

  depends_on = [
    azurerm_role_assignment.des_kv_crypto,
  ]
}
