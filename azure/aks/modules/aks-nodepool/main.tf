###############################################################################
# aks-nodepool module — azurerm_kubernetes_cluster_node_pool
#
# ignore_changes cannot be set conditionally, so the pool is declared twice and
# selected by var.ignore_node_count_changes. The "managed" variant lets the
# cluster autoscaler own node_count (drift ignored); the "fixed" variant keeps
# Terraform authoritative over node_count. Exactly one is ever created.
###############################################################################

locals {
  create_managed = var.ignore_node_count_changes ? 1 : 0
  create_fixed   = var.ignore_node_count_changes ? 0 : 1
}

# Autoscaler-owned pool: Terraform ignores node_count drift.
resource "azurerm_kubernetes_cluster_node_pool" "managed" {
  count = local.create_managed

  kubernetes_cluster_id = var.kubernetes_cluster_id
  name                  = var.name
  vm_size               = var.vm_size
  orchestrator_version  = var.orchestrator_version
  mode                  = var.mode

  priority        = var.priority
  spot_max_price  = var.priority == "Spot" ? var.spot_max_price : null
  eviction_policy = var.priority == "Spot" ? var.eviction_policy : null

  node_count           = var.node_count
  auto_scaling_enabled = var.auto_scaling_enabled
  min_count            = var.auto_scaling_enabled ? var.min_count : null
  max_count            = var.auto_scaling_enabled ? var.max_count : null
  max_pods             = var.max_pods
  scale_down_mode      = var.scale_down_mode
  zones                = var.zones

  os_type           = var.os_type
  os_sku            = var.os_sku
  os_disk_size_gb   = var.os_disk_size_gb
  os_disk_type      = var.os_disk_type
  kubelet_disk_type = var.kubelet_disk_type
  workload_runtime  = var.workload_runtime
  ultra_ssd_enabled = var.ultra_ssd_enabled
  fips_enabled      = var.fips_enabled

  host_encryption_enabled = var.host_encryption_enabled

  vnet_subnet_id                = var.vnet_subnet_id
  pod_subnet_id                 = var.pod_subnet_id
  node_public_ip_enabled        = var.node_public_ip_enabled
  node_public_ip_prefix_id      = var.node_public_ip_prefix_id
  proximity_placement_group_id  = var.proximity_placement_group_id
  capacity_reservation_group_id = var.capacity_reservation_group_id
  host_group_id                 = var.host_group_id
  gpu_instance                  = var.gpu_instance
  snapshot_id                   = var.snapshot_id

  node_labels = var.node_labels
  node_taints = var.node_taints
  tags        = var.tags

  upgrade_settings {
    max_surge                     = var.upgrade_settings.max_surge
    drain_timeout_in_minutes      = var.upgrade_settings.drain_timeout_in_minutes
    node_soak_duration_in_minutes = var.upgrade_settings.node_soak_duration_in_minutes
  }

  dynamic "kubelet_config" {
    for_each = var.kubelet_config == null ? [] : [var.kubelet_config]
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
    for_each = var.linux_os_config == null ? [] : [var.linux_os_config]
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
    for_each = var.node_network_profile == null ? [] : [var.node_network_profile]
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

  dynamic "windows_profile" {
    for_each = var.windows_profile == null ? [] : [var.windows_profile]
    content {
      outbound_nat_enabled = windows_profile.value.outbound_nat_enabled
    }
  }

  timeouts {
    create = var.create_timeout
    update = var.update_timeout
    read   = var.read_timeout
    delete = var.delete_timeout
  }

  lifecycle {
    ignore_changes = [node_count]
  }
}

# Terraform-authoritative pool: node_count is fully managed by Terraform.
resource "azurerm_kubernetes_cluster_node_pool" "fixed" {
  count = local.create_fixed

  kubernetes_cluster_id = var.kubernetes_cluster_id
  name                  = var.name
  vm_size               = var.vm_size
  orchestrator_version  = var.orchestrator_version
  mode                  = var.mode

  priority        = var.priority
  spot_max_price  = var.priority == "Spot" ? var.spot_max_price : null
  eviction_policy = var.priority == "Spot" ? var.eviction_policy : null

  node_count           = var.node_count
  auto_scaling_enabled = var.auto_scaling_enabled
  min_count            = var.auto_scaling_enabled ? var.min_count : null
  max_count            = var.auto_scaling_enabled ? var.max_count : null
  max_pods             = var.max_pods
  scale_down_mode      = var.scale_down_mode
  zones                = var.zones

  os_type           = var.os_type
  os_sku            = var.os_sku
  os_disk_size_gb   = var.os_disk_size_gb
  os_disk_type      = var.os_disk_type
  kubelet_disk_type = var.kubelet_disk_type
  workload_runtime  = var.workload_runtime
  ultra_ssd_enabled = var.ultra_ssd_enabled
  fips_enabled      = var.fips_enabled

  host_encryption_enabled = var.host_encryption_enabled

  vnet_subnet_id                = var.vnet_subnet_id
  pod_subnet_id                 = var.pod_subnet_id
  node_public_ip_enabled        = var.node_public_ip_enabled
  node_public_ip_prefix_id      = var.node_public_ip_prefix_id
  proximity_placement_group_id  = var.proximity_placement_group_id
  capacity_reservation_group_id = var.capacity_reservation_group_id
  host_group_id                 = var.host_group_id
  gpu_instance                  = var.gpu_instance
  snapshot_id                   = var.snapshot_id

  node_labels = var.node_labels
  node_taints = var.node_taints
  tags        = var.tags

  upgrade_settings {
    max_surge                     = var.upgrade_settings.max_surge
    drain_timeout_in_minutes      = var.upgrade_settings.drain_timeout_in_minutes
    node_soak_duration_in_minutes = var.upgrade_settings.node_soak_duration_in_minutes
  }

  dynamic "kubelet_config" {
    for_each = var.kubelet_config == null ? [] : [var.kubelet_config]
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
    for_each = var.linux_os_config == null ? [] : [var.linux_os_config]
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
    for_each = var.node_network_profile == null ? [] : [var.node_network_profile]
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

  dynamic "windows_profile" {
    for_each = var.windows_profile == null ? [] : [var.windows_profile]
    content {
      outbound_nat_enabled = windows_profile.value.outbound_nat_enabled
    }
  }

  timeouts {
    create = var.create_timeout
    update = var.update_timeout
    read   = var.read_timeout
    delete = var.delete_timeout
  }
}
