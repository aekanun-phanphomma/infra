###############################################################################
# aks-cluster module — azurerm_kubernetes_cluster
#
# Every optional capability of the resource is wired through a dynamic block so
# that the surface area stays complete while the rendered configuration only
# contains what the caller actually requests.
###############################################################################

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  node_resource_group = var.node_resource_group

  kubernetes_version = var.kubernetes_version
  sku_tier           = var.sku_tier
  support_plan       = var.support_plan
  edge_zone          = var.edge_zone

  dns_prefix                 = var.dns_prefix
  dns_prefix_private_cluster = var.dns_prefix_private_cluster

  # Private cluster / API server
  private_cluster_enabled             = var.private_cluster_enabled
  private_dns_zone_id                 = var.private_dns_zone_id
  private_cluster_public_fqdn_enabled = var.private_cluster_public_fqdn_enabled

  # Feature toggles
  role_based_access_control_enabled = var.role_based_access_control_enabled
  local_account_disabled            = var.local_account_disabled
  oidc_issuer_enabled               = var.oidc_issuer_enabled
  workload_identity_enabled         = var.workload_identity_enabled
  azure_policy_enabled              = var.azure_policy_enabled
  http_application_routing_enabled  = var.http_application_routing_enabled
  open_service_mesh_enabled         = var.open_service_mesh_enabled
  run_command_enabled               = var.run_command_enabled
  cost_analysis_enabled             = var.cost_analysis_enabled
  image_cleaner_enabled             = var.image_cleaner_enabled
  image_cleaner_interval_hours      = var.image_cleaner_interval_hours

  # Upgrade channels
  automatic_upgrade_channel = var.automatic_upgrade_channel
  node_os_upgrade_channel   = var.node_os_upgrade_channel

  # Encryption
  disk_encryption_set_id              = var.disk_encryption_set_id
  custom_ca_trust_certificates_base64 = length(var.custom_ca_trust_certificates_base64) > 0 ? var.custom_ca_trust_certificates_base64 : null

  tags = var.tags

  # --------------------------------------------------------------------------
  # Default (system) node pool — required block
  # --------------------------------------------------------------------------
  default_node_pool {
    name                          = var.default_node_pool.name
    vm_size                       = var.default_node_pool.vm_size
    node_count                    = var.default_node_pool.node_count
    auto_scaling_enabled          = var.default_node_pool.auto_scaling_enabled
    min_count                     = var.default_node_pool.auto_scaling_enabled ? var.default_node_pool.min_count : null
    max_count                     = var.default_node_pool.auto_scaling_enabled ? var.default_node_pool.max_count : null
    max_pods                      = var.default_node_pool.max_pods
    vnet_subnet_id                = var.default_node_pool.vnet_subnet_id
    pod_subnet_id                 = var.default_node_pool.pod_subnet_id
    zones                         = var.default_node_pool.zones
    os_disk_size_gb               = var.default_node_pool.os_disk_size_gb
    os_disk_type                  = var.default_node_pool.os_disk_type
    os_sku                        = var.default_node_pool.os_sku
    type                          = var.default_node_pool.type
    kubelet_disk_type             = var.default_node_pool.kubelet_disk_type
    scale_down_mode               = var.default_node_pool.scale_down_mode
    workload_runtime              = var.default_node_pool.workload_runtime
    node_public_ip_enabled        = var.default_node_pool.node_public_ip_enabled
    host_encryption_enabled       = var.default_node_pool.host_encryption_enabled
    fips_enabled                  = var.default_node_pool.fips_enabled
    only_critical_addons_enabled  = var.default_node_pool.only_critical_addons_enabled
    ultra_ssd_enabled             = var.default_node_pool.ultra_ssd_enabled
    gpu_instance                  = var.default_node_pool.gpu_instance
    proximity_placement_group_id  = var.default_node_pool.proximity_placement_group_id
    capacity_reservation_group_id = var.default_node_pool.capacity_reservation_group_id
    node_public_ip_prefix_id      = var.default_node_pool.node_public_ip_prefix_id
    snapshot_id                   = var.default_node_pool.snapshot_id
    temporary_name_for_rotation   = var.default_node_pool.temporary_name_for_rotation
    node_labels                   = var.default_node_pool.node_labels
    tags                          = var.default_node_pool.tags

    dynamic "upgrade_settings" {
      for_each = var.default_node_pool.upgrade_settings == null ? [] : [var.default_node_pool.upgrade_settings]
      content {
        max_surge                     = upgrade_settings.value.max_surge
        drain_timeout_in_minutes      = upgrade_settings.value.drain_timeout_in_minutes
        node_soak_duration_in_minutes = upgrade_settings.value.node_soak_duration_in_minutes
      }
    }

    dynamic "kubelet_config" {
      for_each = var.default_node_pool.kubelet_config == null ? [] : [var.default_node_pool.kubelet_config]
      content {
        cpu_manager_policy        = kubelet_config.value.cpu_manager_policy
        cpu_cfs_quota_enabled     = kubelet_config.value.cpu_cfs_quota_enabled
        cpu_cfs_quota_period      = kubelet_config.value.cpu_cfs_quota_period
        image_gc_high_threshold   = kubelet_config.value.image_gc_high_threshold
        image_gc_low_threshold    = kubelet_config.value.image_gc_low_threshold
        topology_manager_policy   = kubelet_config.value.topology_manager_policy
        allowed_unsafe_sysctls    = kubelet_config.value.allowed_unsafe_sysctls
        container_log_max_size_mb = kubelet_config.value.container_log_max_size_mb
        container_log_max_line    = kubelet_config.value.container_log_max_line
        pod_max_pid               = kubelet_config.value.pod_max_pid
      }
    }

    dynamic "linux_os_config" {
      for_each = var.default_node_pool.linux_os_config == null ? [] : [var.default_node_pool.linux_os_config]
      content {
        swap_file_size_mb             = linux_os_config.value.swap_file_size_mb
        transparent_huge_page_enabled = linux_os_config.value.transparent_huge_page_enabled
        transparent_huge_page_defrag  = linux_os_config.value.transparent_huge_page_defrag

        dynamic "sysctl_config" {
          for_each = linux_os_config.value.sysctl_config == null ? [] : [linux_os_config.value.sysctl_config]
          content {
            fs_aio_max_nr                      = sysctl_config.value.fs_aio_max_nr
            fs_file_max                        = sysctl_config.value.fs_file_max
            fs_inotify_max_user_watches        = sysctl_config.value.fs_inotify_max_user_watches
            fs_nr_open                         = sysctl_config.value.fs_nr_open
            kernel_threads_max                 = sysctl_config.value.kernel_threads_max
            net_core_netdev_max_backlog        = sysctl_config.value.net_core_netdev_max_backlog
            net_core_optmem_max                = sysctl_config.value.net_core_optmem_max
            net_core_rmem_default              = sysctl_config.value.net_core_rmem_default
            net_core_rmem_max                  = sysctl_config.value.net_core_rmem_max
            net_core_somaxconn                 = sysctl_config.value.net_core_somaxconn
            net_core_wmem_default              = sysctl_config.value.net_core_wmem_default
            net_core_wmem_max                  = sysctl_config.value.net_core_wmem_max
            net_ipv4_ip_local_port_range_min   = sysctl_config.value.net_ipv4_ip_local_port_range_min
            net_ipv4_ip_local_port_range_max   = sysctl_config.value.net_ipv4_ip_local_port_range_max
            net_ipv4_neigh_default_gc_thresh1  = sysctl_config.value.net_ipv4_neigh_default_gc_thresh1
            net_ipv4_neigh_default_gc_thresh2  = sysctl_config.value.net_ipv4_neigh_default_gc_thresh2
            net_ipv4_neigh_default_gc_thresh3  = sysctl_config.value.net_ipv4_neigh_default_gc_thresh3
            net_ipv4_tcp_fin_timeout           = sysctl_config.value.net_ipv4_tcp_fin_timeout
            net_ipv4_tcp_keepalive_intvl       = sysctl_config.value.net_ipv4_tcp_keepalive_intvl
            net_ipv4_tcp_keepalive_probes      = sysctl_config.value.net_ipv4_tcp_keepalive_probes
            net_ipv4_tcp_keepalive_time        = sysctl_config.value.net_ipv4_tcp_keepalive_time
            net_ipv4_tcp_max_syn_backlog       = sysctl_config.value.net_ipv4_tcp_max_syn_backlog
            net_ipv4_tcp_max_tw_buckets        = sysctl_config.value.net_ipv4_tcp_max_tw_buckets
            net_ipv4_tcp_tw_reuse              = sysctl_config.value.net_ipv4_tcp_tw_reuse
            net_netfilter_nf_conntrack_buckets = sysctl_config.value.net_netfilter_nf_conntrack_buckets
            net_netfilter_nf_conntrack_max     = sysctl_config.value.net_netfilter_nf_conntrack_max
            vm_max_map_count                   = sysctl_config.value.vm_max_map_count
            vm_swappiness                      = sysctl_config.value.vm_swappiness
            vm_vfs_cache_pressure              = sysctl_config.value.vm_vfs_cache_pressure
          }
        }
      }
    }

    dynamic "node_network_profile" {
      for_each = var.default_node_pool.node_network_profile == null ? [] : [var.default_node_pool.node_network_profile]
      content {
        node_public_ip_tags            = node_network_profile.value.node_public_ip_tags
        application_security_group_ids = node_network_profile.value.application_security_group_ids

        dynamic "allowed_host_ports" {
          for_each = node_network_profile.value.allowed_host_ports
          content {
            port_start = allowed_host_ports.value.port_start
            port_end   = allowed_host_ports.value.port_end
            protocol   = allowed_host_ports.value.protocol
          }
        }
      }
    }
  }

  # --------------------------------------------------------------------------
  # Identity / service principal
  # --------------------------------------------------------------------------
  dynamic "identity" {
    for_each = var.service_principal == null ? [var.identity] : []
    content {
      type         = identity.value.type
      identity_ids = identity.value.identity_ids
    }
  }

  dynamic "service_principal" {
    for_each = var.service_principal == null ? [] : [var.service_principal]
    content {
      client_id     = service_principal.value.client_id
      client_secret = service_principal.value.client_secret
    }
  }

  # --------------------------------------------------------------------------
  # API server access profile
  # --------------------------------------------------------------------------
  dynamic "api_server_access_profile" {
    for_each = var.api_server_access_profile == null ? [] : [var.api_server_access_profile]
    content {
      authorized_ip_ranges = api_server_access_profile.value.authorized_ip_ranges
    }
  }

  # --------------------------------------------------------------------------
  # Network profile
  # --------------------------------------------------------------------------
  network_profile {
    network_plugin      = var.network_profile.network_plugin
    network_plugin_mode = var.network_profile.network_plugin_mode
    network_policy      = var.network_profile.network_policy
    network_mode        = var.network_profile.network_mode
    network_data_plane  = var.network_profile.network_data_plane
    dns_service_ip      = var.network_profile.dns_service_ip
    service_cidr        = var.network_profile.service_cidr
    service_cidrs       = var.network_profile.service_cidrs
    pod_cidr            = var.network_profile.pod_cidr
    pod_cidrs           = var.network_profile.pod_cidrs
    ip_versions         = var.network_profile.ip_versions
    outbound_type       = var.network_profile.outbound_type
    load_balancer_sku   = var.network_profile.load_balancer_sku

    dynamic "load_balancer_profile" {
      for_each = var.network_profile.load_balancer_profile == null ? [] : [var.network_profile.load_balancer_profile]
      content {
        managed_outbound_ip_count   = load_balancer_profile.value.managed_outbound_ip_count
        managed_outbound_ipv6_count = load_balancer_profile.value.managed_outbound_ipv6_count
        outbound_ip_address_ids     = load_balancer_profile.value.outbound_ip_address_ids
        outbound_ip_prefix_ids      = load_balancer_profile.value.outbound_ip_prefix_ids
        outbound_ports_allocated    = load_balancer_profile.value.outbound_ports_allocated
        idle_timeout_in_minutes     = load_balancer_profile.value.idle_timeout_in_minutes
      }
    }

    dynamic "nat_gateway_profile" {
      for_each = var.network_profile.nat_gateway_profile == null ? [] : [var.network_profile.nat_gateway_profile]
      content {
        idle_timeout_in_minutes   = nat_gateway_profile.value.idle_timeout_in_minutes
        managed_outbound_ip_count = nat_gateway_profile.value.managed_outbound_ip_count
      }
    }
  }

  # --------------------------------------------------------------------------
  # Azure AD RBAC
  # --------------------------------------------------------------------------
  dynamic "azure_active_directory_role_based_access_control" {
    for_each = var.azure_active_directory_role_based_access_control == null ? [] : [var.azure_active_directory_role_based_access_control]
    content {
      tenant_id              = azure_active_directory_role_based_access_control.value.tenant_id
      azure_rbac_enabled     = azure_active_directory_role_based_access_control.value.azure_rbac_enabled
      admin_group_object_ids = azure_active_directory_role_based_access_control.value.admin_group_object_ids
    }
  }

  # --------------------------------------------------------------------------
  # Autoscaler profile
  # --------------------------------------------------------------------------
  dynamic "auto_scaler_profile" {
    for_each = var.auto_scaler_profile == null ? [] : [var.auto_scaler_profile]
    content {
      balance_similar_node_groups                   = auto_scaler_profile.value.balance_similar_node_groups
      expander                                      = auto_scaler_profile.value.expander
      max_graceful_termination_sec                  = auto_scaler_profile.value.max_graceful_termination_sec
      max_node_provisioning_time                    = auto_scaler_profile.value.max_node_provisioning_time
      max_unready_nodes                             = auto_scaler_profile.value.max_unready_nodes
      max_unready_percentage                        = auto_scaler_profile.value.max_unready_percentage
      new_pod_scale_up_delay                        = auto_scaler_profile.value.new_pod_scale_up_delay
      scale_down_delay_after_add                    = auto_scaler_profile.value.scale_down_delay_after_add
      scale_down_delay_after_delete                 = auto_scaler_profile.value.scale_down_delay_after_delete
      scale_down_delay_after_failure                = auto_scaler_profile.value.scale_down_delay_after_failure
      scan_interval                                 = auto_scaler_profile.value.scan_interval
      scale_down_unneeded                           = auto_scaler_profile.value.scale_down_unneeded
      scale_down_unready                            = auto_scaler_profile.value.scale_down_unready
      scale_down_utilization_threshold              = auto_scaler_profile.value.scale_down_utilization_threshold
      empty_bulk_delete_max                         = auto_scaler_profile.value.empty_bulk_delete_max
      skip_nodes_with_local_storage                 = auto_scaler_profile.value.skip_nodes_with_local_storage
      skip_nodes_with_system_pods                   = auto_scaler_profile.value.skip_nodes_with_system_pods
      daemonset_eviction_for_empty_nodes_enabled    = auto_scaler_profile.value.daemonset_eviction_for_empty_nodes_enabled
      daemonset_eviction_for_occupied_nodes_enabled = auto_scaler_profile.value.daemonset_eviction_for_occupied_nodes_enabled
      ignore_daemonsets_utilization_enabled         = auto_scaler_profile.value.ignore_daemonsets_utilization_enabled
    }
  }

  # --------------------------------------------------------------------------
  # KMS etcd encryption
  # --------------------------------------------------------------------------
  dynamic "key_management_service" {
    for_each = var.key_management_service == null ? [] : [var.key_management_service]
    content {
      key_vault_key_id         = key_management_service.value.key_vault_key_id
      key_vault_network_access = key_management_service.value.key_vault_network_access
    }
  }

  # --------------------------------------------------------------------------
  # Key Vault secrets provider (CSI)
  # --------------------------------------------------------------------------
  dynamic "key_vault_secrets_provider" {
    for_each = var.key_vault_secrets_provider == null ? [] : [var.key_vault_secrets_provider]
    content {
      secret_rotation_enabled  = key_vault_secrets_provider.value.secret_rotation_enabled
      secret_rotation_interval = key_vault_secrets_provider.value.secret_rotation_interval
    }
  }

  # --------------------------------------------------------------------------
  # Storage profile
  # --------------------------------------------------------------------------
  dynamic "storage_profile" {
    for_each = var.storage_profile == null ? [] : [var.storage_profile]
    content {
      blob_driver_enabled         = storage_profile.value.blob_driver_enabled
      disk_driver_enabled         = storage_profile.value.disk_driver_enabled
      file_driver_enabled         = storage_profile.value.file_driver_enabled
      snapshot_controller_enabled = storage_profile.value.snapshot_controller_enabled
    }
  }

  # --------------------------------------------------------------------------
  # Managed Istio service mesh
  # --------------------------------------------------------------------------
  dynamic "service_mesh_profile" {
    for_each = var.service_mesh_profile == null ? [] : [var.service_mesh_profile]
    content {
      mode                             = service_mesh_profile.value.mode
      revisions                        = service_mesh_profile.value.revisions
      internal_ingress_gateway_enabled = service_mesh_profile.value.internal_ingress_gateway_enabled
      external_ingress_gateway_enabled = service_mesh_profile.value.external_ingress_gateway_enabled

      dynamic "certificate_authority" {
        for_each = service_mesh_profile.value.certificate_authority == null ? [] : [service_mesh_profile.value.certificate_authority]
        content {
          key_vault_id           = certificate_authority.value.key_vault_id
          root_cert_object_name  = certificate_authority.value.root_cert_object_name
          cert_chain_object_name = certificate_authority.value.cert_chain_object_name
          cert_object_name       = certificate_authority.value.cert_object_name
          key_object_name        = certificate_authority.value.key_object_name
        }
      }
    }
  }

  # --------------------------------------------------------------------------
  # Workload autoscaler (KEDA / VPA)
  # --------------------------------------------------------------------------
  dynamic "workload_autoscaler_profile" {
    for_each = var.workload_autoscaler_profile == null ? [] : [var.workload_autoscaler_profile]
    content {
      keda_enabled                    = workload_autoscaler_profile.value.keda_enabled
      vertical_pod_autoscaler_enabled = workload_autoscaler_profile.value.vertical_pod_autoscaler_enabled
    }
  }

  # --------------------------------------------------------------------------
  # Observability add-ons
  # --------------------------------------------------------------------------
  dynamic "oms_agent" {
    for_each = var.oms_agent == null ? [] : [var.oms_agent]
    content {
      log_analytics_workspace_id      = oms_agent.value.log_analytics_workspace_id
      msi_auth_for_monitoring_enabled = oms_agent.value.msi_auth_for_monitoring_enabled
    }
  }

  dynamic "monitor_metrics" {
    for_each = var.monitor_metrics == null ? [] : [var.monitor_metrics]
    content {
      annotations_allowed = monitor_metrics.value.annotations_allowed
      labels_allowed      = monitor_metrics.value.labels_allowed
    }
  }

  dynamic "microsoft_defender" {
    for_each = var.microsoft_defender == null ? [] : [var.microsoft_defender]
    content {
      log_analytics_workspace_id = microsoft_defender.value.log_analytics_workspace_id
    }
  }

  # --------------------------------------------------------------------------
  # Ingress / connector add-ons
  # --------------------------------------------------------------------------
  dynamic "ingress_application_gateway" {
    for_each = var.ingress_application_gateway == null ? [] : [var.ingress_application_gateway]
    content {
      gateway_id   = ingress_application_gateway.value.gateway_id
      gateway_name = ingress_application_gateway.value.gateway_name
      subnet_cidr  = ingress_application_gateway.value.subnet_cidr
      subnet_id    = ingress_application_gateway.value.subnet_id
    }
  }

  dynamic "aci_connector_linux" {
    for_each = var.aci_connector_linux == null ? [] : [var.aci_connector_linux]
    content {
      subnet_name = aci_connector_linux.value.subnet_name
    }
  }

  dynamic "confidential_computing" {
    for_each = var.confidential_computing == null ? [] : [var.confidential_computing]
    content {
      sgx_quote_helper_enabled = confidential_computing.value.sgx_quote_helper_enabled
    }
  }

  dynamic "web_app_routing" {
    for_each = var.web_app_routing == null ? [] : [var.web_app_routing]
    content {
      dns_zone_ids             = web_app_routing.value.dns_zone_ids
      default_nginx_controller = web_app_routing.value.default_nginx_controller
    }
  }

  # --------------------------------------------------------------------------
  # HTTP proxy
  # --------------------------------------------------------------------------
  dynamic "http_proxy_config" {
    for_each = var.http_proxy_config == null ? [] : [var.http_proxy_config]
    content {
      http_proxy  = http_proxy_config.value.http_proxy
      https_proxy = http_proxy_config.value.https_proxy
      no_proxy    = http_proxy_config.value.no_proxy
      trusted_ca  = http_proxy_config.value.trusted_ca
    }
  }

  # --------------------------------------------------------------------------
  # OS profiles
  # --------------------------------------------------------------------------
  dynamic "linux_profile" {
    for_each = var.linux_profile == null ? [] : [var.linux_profile]
    content {
      admin_username = linux_profile.value.admin_username
      ssh_key {
        key_data = linux_profile.value.ssh_key
      }
    }
  }

  dynamic "windows_profile" {
    for_each = var.windows_profile == null ? [] : [var.windows_profile]
    content {
      admin_username = windows_profile.value.admin_username
      admin_password = windows_profile.value.admin_password
      license        = windows_profile.value.license

      dynamic "gmsa" {
        for_each = windows_profile.value.gmsa == null ? [] : [windows_profile.value.gmsa]
        content {
          dns_server  = gmsa.value.dns_server
          root_domain = gmsa.value.root_domain
        }
      }
    }
  }

  # --------------------------------------------------------------------------
  # Maintenance windows
  # --------------------------------------------------------------------------
  dynamic "maintenance_window" {
    for_each = var.maintenance_window == null ? [] : [var.maintenance_window]
    content {
      dynamic "allowed" {
        for_each = maintenance_window.value.allowed
        content {
          day   = allowed.value.day
          hours = allowed.value.hours
        }
      }
      dynamic "not_allowed" {
        for_each = maintenance_window.value.not_allowed
        content {
          start = not_allowed.value.start
          end   = not_allowed.value.end
        }
      }
    }
  }

  dynamic "maintenance_window_auto_upgrade" {
    for_each = var.maintenance_window_auto_upgrade == null ? [] : [var.maintenance_window_auto_upgrade]
    content {
      frequency    = maintenance_window_auto_upgrade.value.frequency
      interval     = maintenance_window_auto_upgrade.value.interval
      duration     = maintenance_window_auto_upgrade.value.duration
      day_of_week  = maintenance_window_auto_upgrade.value.day_of_week
      day_of_month = maintenance_window_auto_upgrade.value.day_of_month
      week_index   = maintenance_window_auto_upgrade.value.week_index
      start_time   = maintenance_window_auto_upgrade.value.start_time
      start_date   = maintenance_window_auto_upgrade.value.start_date
      utc_offset   = maintenance_window_auto_upgrade.value.utc_offset

      dynamic "not_allowed" {
        for_each = maintenance_window_auto_upgrade.value.not_allowed
        content {
          start = not_allowed.value.start
          end   = not_allowed.value.end
        }
      }
    }
  }

  dynamic "maintenance_window_node_os" {
    for_each = var.maintenance_window_node_os == null ? [] : [var.maintenance_window_node_os]
    content {
      frequency    = maintenance_window_node_os.value.frequency
      interval     = maintenance_window_node_os.value.interval
      duration     = maintenance_window_node_os.value.duration
      day_of_week  = maintenance_window_node_os.value.day_of_week
      day_of_month = maintenance_window_node_os.value.day_of_month
      week_index   = maintenance_window_node_os.value.week_index
      start_time   = maintenance_window_node_os.value.start_time
      start_date   = maintenance_window_node_os.value.start_date
      utc_offset   = maintenance_window_node_os.value.utc_offset

      dynamic "not_allowed" {
        for_each = maintenance_window_node_os.value.not_allowed
        content {
          start = not_allowed.value.start
          end   = not_allowed.value.end
        }
      }
    }
  }

  timeouts {
    create = var.create_timeout
    update = var.update_timeout
    read   = var.read_timeout
    delete = var.delete_timeout
  }

  lifecycle {
    ignore_changes = [
      # AKS bumps the patch version automatically; ignore so plans stay clean.
      kubernetes_version,
      # Autoscaler manages the system pool size after creation.
      default_node_pool[0].node_count,
    ]

    precondition {
      condition     = var.workload_identity_enabled ? var.oidc_issuer_enabled : true
      error_message = "workload_identity_enabled requires oidc_issuer_enabled = true."
    }

    precondition {
      condition     = var.dns_prefix == null || var.dns_prefix_private_cluster == null
      error_message = "Set only one of dns_prefix or dns_prefix_private_cluster."
    }
  }
}
