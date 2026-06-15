###############################################################################
# aks-cluster module — variables
#
# This module intentionally exposes (almost) every argument supported by the
# azurerm_kubernetes_cluster resource, even ones not used by the default root
# configuration. Complex blocks are modelled as optional() object types so the
# corresponding dynamic blocks are only emitted when a value is supplied.
###############################################################################

# ----------------------------------------------------------------------------
# Core cluster configuration
# ----------------------------------------------------------------------------
variable "name" {
  description = "Name of the managed Kubernetes cluster. Changing this forces a new resource."
  type        = string
}

variable "location" {
  description = "Azure region in which the cluster is created."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group in which to create the cluster."
  type        = string
}

variable "node_resource_group" {
  description = "Name of the auto-generated resource group that holds the cluster node resources. Null lets Azure pick a name."
  type        = string
  default     = null
}

variable "kubernetes_version" {
  description = "Version of Kubernetes for the control plane. Null tracks the AKS default. Patch version is managed by AKS unless pinned."
  type        = string
  default     = null
}

variable "sku_tier" {
  description = "Control-plane SKU tier. One of Free, Standard or Premium. Standard or Premium is required for an uptime SLA."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku_tier)
    error_message = "sku_tier must be one of: Free, Standard, Premium."
  }
}

variable "support_plan" {
  description = "Support plan for the cluster. One of KubernetesOfficial or AKSLongTermSupport."
  type        = string
  default     = "KubernetesOfficial"
}

variable "dns_prefix" {
  description = "DNS prefix for the cluster (public/standard clusters). Mutually exclusive with dns_prefix_private_cluster."
  type        = string
  default     = null
}

variable "dns_prefix_private_cluster" {
  description = "DNS prefix to use with a private cluster that brings its own private DNS zone. Mutually exclusive with dns_prefix."
  type        = string
  default     = null
}

variable "edge_zone" {
  description = "Edge Zone within the Azure region where the cluster should exist."
  type        = string
  default     = null
}

variable "tags" {
  description = "Map of tags applied to the cluster."
  type        = map(string)
  default     = {}
}

# ----------------------------------------------------------------------------
# Private cluster / API server access
# ----------------------------------------------------------------------------
variable "private_cluster_enabled" {
  description = "Deploy the cluster with a private API server endpoint."
  type        = bool
  default     = true
}

variable "private_dns_zone_id" {
  description = "Private DNS zone ID for the API server. Use 'System', 'None', or a resource ID. Null lets AKS manage it."
  type        = string
  default     = null
}

variable "private_cluster_public_fqdn_enabled" {
  description = "Also expose a public FQDN for a private cluster."
  type        = bool
  default     = false
}

variable "api_server_access_profile" {
  description = "API server access profile. authorized_ip_ranges restricts which CIDRs may reach the API server (public clusters only)."
  type = object({
    authorized_ip_ranges = optional(set(string))
  })
  default = null
}

# ----------------------------------------------------------------------------
# Identity
# ----------------------------------------------------------------------------
variable "identity" {
  description = "Managed identity for the control plane. type is SystemAssigned or UserAssigned; identity_ids required for UserAssigned."
  type = object({
    type         = string
    identity_ids = optional(list(string))
  })
  default = {
    type = "SystemAssigned"
  }
}

variable "service_principal" {
  description = "Service principal credentials (legacy alternative to managed identity). Prefer identity. Leave null to use managed identity."
  type = object({
    client_id     = string
    client_secret = string
  })
  default = null
}

# ----------------------------------------------------------------------------
# Feature toggles / channels
# ----------------------------------------------------------------------------
variable "role_based_access_control_enabled" {
  description = "Enable Kubernetes RBAC on the cluster."
  type        = bool
  default     = true
}

variable "local_account_disabled" {
  description = "Disable local (static) admin accounts. Requires AAD RBAC. Recommended for production."
  type        = bool
  default     = true
}

variable "oidc_issuer_enabled" {
  description = "Enable the OIDC issuer URL. Required for workload identity."
  type        = bool
  default     = true
}

variable "workload_identity_enabled" {
  description = "Enable Microsoft Entra Workload Identity. Requires oidc_issuer_enabled = true."
  type        = bool
  default     = true
}

variable "azure_policy_enabled" {
  description = "Enable the Azure Policy add-on (Gatekeeper)."
  type        = bool
  default     = true
}

variable "http_application_routing_enabled" {
  description = "Enable the legacy HTTP application routing add-on (not recommended for production)."
  type        = bool
  default     = false
}

variable "open_service_mesh_enabled" {
  description = "Enable the Open Service Mesh add-on."
  type        = bool
  default     = false
}

variable "run_command_enabled" {
  description = "Enable the az aks command invoke run-command feature."
  type        = bool
  default     = true
}

variable "cost_analysis_enabled" {
  description = "Enable cost analysis. Requires sku_tier of Standard or Premium."
  type        = bool
  default     = false
}

variable "image_cleaner_enabled" {
  description = "Enable the Image Cleaner (Eraser) add-on to remove unused images from nodes."
  type        = bool
  default     = false
}

variable "image_cleaner_interval_hours" {
  description = "Interval in hours for the Image Cleaner scan. Between 24 and 2160."
  type        = number
  default     = 48
}

variable "automatic_upgrade_channel" {
  description = "Control-plane upgrade channel. One of patch, rapid, node-image, stable, or null to disable."
  type        = string
  default     = "stable"

  validation {
    condition     = var.automatic_upgrade_channel == null || contains(["patch", "rapid", "node-image", "stable"], coalesce(var.automatic_upgrade_channel, "stable"))
    error_message = "automatic_upgrade_channel must be one of: patch, rapid, node-image, stable, or null."
  }
}

variable "node_os_upgrade_channel" {
  description = "Node OS image upgrade channel. One of Unmanaged, SecurityPatch, NodeImage, None."
  type        = string
  default     = "NodeImage"

  validation {
    condition     = contains(["Unmanaged", "SecurityPatch", "NodeImage", "None"], var.node_os_upgrade_channel)
    error_message = "node_os_upgrade_channel must be one of: Unmanaged, SecurityPatch, NodeImage, None."
  }
}

variable "custom_ca_trust_certificates_base64" {
  description = "List of up to 10 base64-encoded CA certificates added to the node trust store."
  type        = list(string)
  default     = []
}

# ----------------------------------------------------------------------------
# Disk encryption (Customer Managed Keys)
# ----------------------------------------------------------------------------
variable "disk_encryption_set_id" {
  description = "Disk Encryption Set ID used to encrypt node OS and data disks with a customer-managed key."
  type        = string
  default     = null
}

variable "key_management_service" {
  description = "KMS etcd encryption configuration backed by Key Vault."
  type = object({
    key_vault_key_id         = string
    key_vault_network_access = optional(string, "Public")
  })
  default = null
}

# ----------------------------------------------------------------------------
# Default (system) node pool
# ----------------------------------------------------------------------------
variable "default_node_pool" {
  description = "Configuration for the default (system) node pool. This pool is managed inline with the cluster."
  type = object({
    name                          = string
    vm_size                       = string
    node_count                    = optional(number)
    auto_scaling_enabled          = optional(bool, false)
    min_count                     = optional(number)
    max_count                     = optional(number)
    max_pods                      = optional(number)
    vnet_subnet_id                = optional(string)
    pod_subnet_id                 = optional(string)
    zones                         = optional(list(string))
    os_disk_size_gb               = optional(number)
    os_disk_type                  = optional(string, "Managed")
    os_sku                        = optional(string)
    type                          = optional(string, "VirtualMachineScaleSets")
    kubelet_disk_type             = optional(string)
    scale_down_mode               = optional(string, "Delete")
    workload_runtime              = optional(string)
    node_public_ip_enabled        = optional(bool, false)
    host_encryption_enabled       = optional(bool, false)
    fips_enabled                  = optional(bool, false)
    only_critical_addons_enabled  = optional(bool, true)
    ultra_ssd_enabled             = optional(bool, false)
    gpu_instance                  = optional(string)
    proximity_placement_group_id  = optional(string)
    capacity_reservation_group_id = optional(string)
    node_public_ip_prefix_id      = optional(string)
    snapshot_id                   = optional(string)
    temporary_name_for_rotation   = optional(string, "systmp")
    node_labels                   = optional(map(string), {})
    tags                          = optional(map(string), {})

    upgrade_settings = optional(object({
      max_surge                     = string
      drain_timeout_in_minutes      = optional(number)
      node_soak_duration_in_minutes = optional(number)
    }))

    kubelet_config = optional(object({
      cpu_manager_policy        = optional(string)
      cpu_cfs_quota_enabled     = optional(bool)
      cpu_cfs_quota_period      = optional(string)
      image_gc_high_threshold   = optional(number)
      image_gc_low_threshold    = optional(number)
      topology_manager_policy   = optional(string)
      allowed_unsafe_sysctls    = optional(set(string))
      container_log_max_size_mb = optional(number)
      container_log_max_line    = optional(number)
      pod_max_pid               = optional(number)
    }))

    linux_os_config = optional(object({
      swap_file_size_mb             = optional(number)
      transparent_huge_page_enabled = optional(string)
      transparent_huge_page_defrag  = optional(string)
      sysctl_config = optional(object({
        fs_aio_max_nr                      = optional(number)
        fs_file_max                        = optional(number)
        fs_inotify_max_user_watches        = optional(number)
        fs_nr_open                         = optional(number)
        kernel_threads_max                 = optional(number)
        net_core_netdev_max_backlog        = optional(number)
        net_core_optmem_max                = optional(number)
        net_core_rmem_default              = optional(number)
        net_core_rmem_max                  = optional(number)
        net_core_somaxconn                 = optional(number)
        net_core_wmem_default              = optional(number)
        net_core_wmem_max                  = optional(number)
        net_ipv4_ip_local_port_range_min   = optional(number)
        net_ipv4_ip_local_port_range_max   = optional(number)
        net_ipv4_neigh_default_gc_thresh1  = optional(number)
        net_ipv4_neigh_default_gc_thresh2  = optional(number)
        net_ipv4_neigh_default_gc_thresh3  = optional(number)
        net_ipv4_tcp_fin_timeout           = optional(number)
        net_ipv4_tcp_keepalive_intvl       = optional(number)
        net_ipv4_tcp_keepalive_probes      = optional(number)
        net_ipv4_tcp_keepalive_time        = optional(number)
        net_ipv4_tcp_max_syn_backlog       = optional(number)
        net_ipv4_tcp_max_tw_buckets        = optional(number)
        net_ipv4_tcp_tw_reuse              = optional(bool)
        net_netfilter_nf_conntrack_buckets = optional(number)
        net_netfilter_nf_conntrack_max     = optional(number)
        vm_max_map_count                   = optional(number)
        vm_swappiness                      = optional(number)
        vm_vfs_cache_pressure              = optional(number)
      }))
    }))

    node_network_profile = optional(object({
      node_public_ip_tags            = optional(map(string))
      application_security_group_ids = optional(list(string))
      allowed_host_ports = optional(list(object({
        port_start = optional(number)
        port_end   = optional(number)
        protocol   = optional(string)
      })), [])
    }))
  })
}

# ----------------------------------------------------------------------------
# Cluster autoscaler profile
# ----------------------------------------------------------------------------
variable "auto_scaler_profile" {
  description = "Tuning knobs for the cluster autoscaler. Null applies AKS defaults."
  type = object({
    balance_similar_node_groups                   = optional(bool)
    expander                                      = optional(string)
    max_graceful_termination_sec                  = optional(number)
    max_node_provisioning_time                    = optional(string)
    max_unready_nodes                             = optional(number)
    max_unready_percentage                        = optional(number)
    new_pod_scale_up_delay                        = optional(string)
    scale_down_delay_after_add                    = optional(string)
    scale_down_delay_after_delete                 = optional(string)
    scale_down_delay_after_failure                = optional(string)
    scan_interval                                 = optional(string)
    scale_down_unneeded                           = optional(string)
    scale_down_unready                            = optional(string)
    scale_down_utilization_threshold              = optional(string)
    empty_bulk_delete_max                         = optional(string)
    skip_nodes_with_local_storage                 = optional(bool)
    skip_nodes_with_system_pods                   = optional(bool)
    daemonset_eviction_for_empty_nodes_enabled    = optional(bool)
    daemonset_eviction_for_occupied_nodes_enabled = optional(bool)
    ignore_daemonsets_utilization_enabled         = optional(bool)
  })
  default = null
}

# ----------------------------------------------------------------------------
# Network profile
# ----------------------------------------------------------------------------
variable "network_profile" {
  description = "Cluster network configuration."
  type = object({
    network_plugin      = string
    network_plugin_mode = optional(string)
    network_policy      = optional(string)
    network_mode        = optional(string)
    network_data_plane  = optional(string)
    dns_service_ip      = optional(string)
    service_cidr        = optional(string)
    service_cidrs       = optional(list(string))
    pod_cidr            = optional(string)
    pod_cidrs           = optional(list(string))
    ip_versions         = optional(list(string))
    outbound_type       = optional(string, "loadBalancer")
    load_balancer_sku   = optional(string, "standard")

    load_balancer_profile = optional(object({
      managed_outbound_ip_count   = optional(number)
      managed_outbound_ipv6_count = optional(number)
      outbound_ip_address_ids     = optional(list(string))
      outbound_ip_prefix_ids      = optional(list(string))
      outbound_ports_allocated    = optional(number)
      idle_timeout_in_minutes     = optional(number)
    }))

    nat_gateway_profile = optional(object({
      idle_timeout_in_minutes   = optional(number)
      managed_outbound_ip_count = optional(number)
    }))
  })
}

# ----------------------------------------------------------------------------
# Azure AD / RBAC integration
# ----------------------------------------------------------------------------
variable "azure_active_directory_role_based_access_control" {
  description = "Microsoft Entra ID (Azure AD) integration for cluster RBAC."
  type = object({
    tenant_id              = optional(string)
    azure_rbac_enabled     = optional(bool, true)
    admin_group_object_ids = optional(list(string))
  })
  default = null
}

# ----------------------------------------------------------------------------
# Add-on / profile blocks
# ----------------------------------------------------------------------------
variable "key_vault_secrets_provider" {
  description = "Azure Key Vault provider for Secrets Store CSI Driver."
  type = object({
    secret_rotation_enabled  = optional(bool, true)
    secret_rotation_interval = optional(string, "2m")
  })
  default = null
}

variable "storage_profile" {
  description = "CSI storage driver configuration."
  type = object({
    blob_driver_enabled         = optional(bool, false)
    disk_driver_enabled         = optional(bool, true)
    file_driver_enabled         = optional(bool, true)
    snapshot_controller_enabled = optional(bool, true)
  })
  default = null
}

variable "service_mesh_profile" {
  description = "Managed Istio service mesh profile. Set null to manage Istio yourself via Helm."
  type = object({
    mode                             = optional(string, "Istio")
    revisions                        = list(string)
    internal_ingress_gateway_enabled = optional(bool)
    external_ingress_gateway_enabled = optional(bool)
    certificate_authority = optional(object({
      key_vault_id           = string
      root_cert_object_name  = string
      cert_chain_object_name = string
      cert_object_name       = string
      key_object_name        = string
    }))
  })
  default = null
}

variable "workload_autoscaler_profile" {
  description = "KEDA and/or Vertical Pod Autoscaler enablement."
  type = object({
    keda_enabled                    = optional(bool, false)
    vertical_pod_autoscaler_enabled = optional(bool, false)
  })
  default = null
}

variable "oms_agent" {
  description = "Azure Monitor (Container Insights) OMS agent add-on."
  type = object({
    log_analytics_workspace_id      = string
    msi_auth_for_monitoring_enabled = optional(bool, true)
  })
  default = null
}

variable "monitor_metrics" {
  description = "Managed Prometheus metrics scraping configuration."
  type = object({
    annotations_allowed = optional(string)
    labels_allowed      = optional(string)
  })
  default = null
}

variable "microsoft_defender" {
  description = "Microsoft Defender for Containers integration."
  type = object({
    log_analytics_workspace_id = string
  })
  default = null
}

variable "ingress_application_gateway" {
  description = "Application Gateway Ingress Controller (AGIC) add-on. Provide either gateway_id or subnet/name details."
  type = object({
    gateway_id   = optional(string)
    gateway_name = optional(string)
    subnet_cidr  = optional(string)
    subnet_id    = optional(string)
  })
  default = null
}

variable "aci_connector_linux" {
  description = "Virtual node (ACI connector) add-on. subnet_name must be delegated to ACI."
  type = object({
    subnet_name = string
  })
  default = null
}

variable "confidential_computing" {
  description = "Confidential computing add-on (SGX device plugin)."
  type = object({
    sgx_quote_helper_enabled = bool
  })
  default = null
}

variable "web_app_routing" {
  description = "Managed NGINX-based application routing add-on."
  type = object({
    dns_zone_ids             = optional(list(string), [])
    default_nginx_controller = optional(string)
  })
  default = null
}

variable "http_proxy_config" {
  description = "Cluster-wide HTTP proxy configuration for nodes."
  type = object({
    http_proxy  = optional(string)
    https_proxy = optional(string)
    no_proxy    = optional(list(string))
    trusted_ca  = optional(string)
  })
  default = null
}

# ----------------------------------------------------------------------------
# OS profiles
# ----------------------------------------------------------------------------
variable "linux_profile" {
  description = "Linux node admin profile with SSH key."
  type = object({
    admin_username = string
    ssh_key        = string
  })
  default = null
}

variable "windows_profile" {
  description = "Windows node admin profile. Required if running Windows node pools."
  type = object({
    admin_username = string
    admin_password = optional(string)
    license        = optional(string)
    gmsa = optional(object({
      dns_server  = string
      root_domain = string
    }))
  })
  default = null
}

# ----------------------------------------------------------------------------
# Maintenance windows
# ----------------------------------------------------------------------------
variable "maintenance_window" {
  description = "Legacy weekly maintenance window for the cluster."
  type = object({
    allowed = optional(list(object({
      day   = string
      hours = list(number)
    })), [])
    not_allowed = optional(list(object({
      start = string
      end   = string
    })), [])
  })
  default = null
}

variable "maintenance_window_auto_upgrade" {
  description = "Maintenance window dedicated to automatic control-plane/cluster upgrades."
  type = object({
    frequency    = string
    interval     = number
    duration     = number
    day_of_week  = optional(string)
    day_of_month = optional(number)
    week_index   = optional(string)
    start_time   = optional(string)
    start_date   = optional(string)
    utc_offset   = optional(string)
    not_allowed = optional(list(object({
      start = string
      end   = string
    })), [])
  })
  default = null
}

variable "maintenance_window_node_os" {
  description = "Maintenance window dedicated to node OS image upgrades."
  type = object({
    frequency    = string
    interval     = number
    duration     = number
    day_of_week  = optional(string)
    day_of_month = optional(number)
    week_index   = optional(string)
    start_time   = optional(string)
    start_date   = optional(string)
    utc_offset   = optional(string)
    not_allowed = optional(list(object({
      start = string
      end   = string
    })), [])
  })
  default = null
}

# ----------------------------------------------------------------------------
# Lifecycle
# ----------------------------------------------------------------------------
variable "create_timeout" {
  description = "Timeout for cluster create."
  type        = string
  default     = "90m"
}

variable "update_timeout" {
  description = "Timeout for cluster update."
  type        = string
  default     = "90m"
}

variable "read_timeout" {
  description = "Timeout for cluster read."
  type        = string
  default     = "5m"
}

variable "delete_timeout" {
  description = "Timeout for cluster delete."
  type        = string
  default     = "90m"
}
