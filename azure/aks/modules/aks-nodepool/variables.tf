###############################################################################
# aks-nodepool module — variables
#
# Wraps azurerm_kubernetes_cluster_node_pool. Exposes the full argument set so
# any user/workload pool can be expressed without touching the module.
###############################################################################

variable "kubernetes_cluster_id" {
  description = "Resource ID of the AKS cluster this node pool attaches to."
  type        = string
}

# ----------------------------------------------------------------------------
# Identity / size
# ----------------------------------------------------------------------------
variable "name" {
  description = "Name of the node pool (1-12 lowercase alphanumeric for Linux, 1-6 for Windows)."
  type        = string
}

variable "vm_size" {
  description = "VM size for the nodes (e.g. Standard_D4s_v5). Forces replacement if changed."
  type        = string
}

variable "orchestrator_version" {
  description = "Kubernetes version for this node pool. Null tracks the control-plane version."
  type        = string
  default     = null
}

variable "mode" {
  description = "Node pool mode: System or User."
  type        = string
  default     = "User"

  validation {
    condition     = contains(["System", "User"], var.mode)
    error_message = "mode must be either System or User."
  }
}

variable "priority" {
  description = "Node pool priority: Regular or Spot."
  type        = string
  default     = "Regular"
}

variable "spot_max_price" {
  description = "Max price (USD) for Spot nodes. -1 means pay up to the on-demand price. Only valid when priority = Spot."
  type        = number
  default     = -1
}

variable "eviction_policy" {
  description = "Eviction policy for Spot nodes: Delete or Deallocate. Only valid when priority = Spot."
  type        = string
  default     = null
}

# ----------------------------------------------------------------------------
# Scaling
# ----------------------------------------------------------------------------
variable "node_count" {
  description = "Initial/desired node count. When autoscaling is enabled this is only the starting value (drift is ignored)."
  type        = number
  default     = 1
}

variable "auto_scaling_enabled" {
  description = "Enable the cluster autoscaler for this pool."
  type        = bool
  default     = true
}

variable "min_count" {
  description = "Minimum node count when autoscaling is enabled."
  type        = number
  default     = 1
}

variable "max_count" {
  description = "Maximum node count when autoscaling is enabled."
  type        = number
  default     = 5
}

variable "max_pods" {
  description = "Maximum number of pods per node."
  type        = number
  default     = null
}

variable "scale_down_mode" {
  description = "Scale-down behaviour: Delete or Deallocate."
  type        = string
  default     = "Delete"
}

variable "zones" {
  description = "Availability zones for the nodes."
  type        = list(string)
  default     = []
}

# ----------------------------------------------------------------------------
# Disk / OS
# ----------------------------------------------------------------------------
variable "os_type" {
  description = "OS type for the nodes: Linux or Windows."
  type        = string
  default     = "Linux"
}

variable "os_sku" {
  description = "OS SKU (e.g. Ubuntu, AzureLinux, Windows2022). Null lets AKS choose."
  type        = string
  default     = null
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB."
  type        = number
  default     = 128
}

variable "os_disk_type" {
  description = "OS disk type: Managed or Ephemeral."
  type        = string
  default     = "Managed"
}

variable "kubelet_disk_type" {
  description = "Where the kubelet stores its data: OS or Temporary."
  type        = string
  default     = null
}

variable "workload_runtime" {
  description = "Workload runtime: OCIContainer, WasmWasi, or KataMshvVmIsolation."
  type        = string
  default     = null
}

variable "ultra_ssd_enabled" {
  description = "Enable UltraSSD support on the nodes."
  type        = bool
  default     = false
}

variable "fips_enabled" {
  description = "Enable a FIPS-compliant node OS image. Forces replacement."
  type        = bool
  default     = false
}

variable "host_encryption_enabled" {
  description = "Enable host-based encryption (encryption at host)."
  type        = bool
  default     = false
}

# ----------------------------------------------------------------------------
# Networking / placement
# ----------------------------------------------------------------------------
variable "vnet_subnet_id" {
  description = "Subnet ID where the nodes are placed."
  type        = string
  default     = null
}

variable "pod_subnet_id" {
  description = "Subnet ID for pods (Azure CNI with dynamic pod IP allocation)."
  type        = string
  default     = null
}

variable "node_public_ip_enabled" {
  description = "Assign a public IP to each node."
  type        = bool
  default     = false
}

variable "node_public_ip_prefix_id" {
  description = "Public IP prefix ID from which node public IPs are drawn."
  type        = string
  default     = null
}

variable "proximity_placement_group_id" {
  description = "Proximity placement group ID for the nodes."
  type        = string
  default     = null
}

variable "capacity_reservation_group_id" {
  description = "Capacity reservation group ID for the nodes."
  type        = string
  default     = null
}

variable "host_group_id" {
  description = "Dedicated host group ID on which to provision the nodes."
  type        = string
  default     = null
}

variable "gpu_instance" {
  description = "GPU instance profile (MIG) for supported VM sizes, e.g. MIG1g."
  type        = string
  default     = null
}

variable "snapshot_id" {
  description = "Snapshot ID from which to create the node pool."
  type        = string
  default     = null
}

# ----------------------------------------------------------------------------
# Labels / taints / tags
# ----------------------------------------------------------------------------
variable "node_labels" {
  description = "Kubernetes labels applied to the nodes."
  type        = map(string)
  default     = {}
}

variable "node_taints" {
  description = "Kubernetes taints applied to the nodes (e.g. key=value:NoSchedule)."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Azure tags applied to the node pool."
  type        = map(string)
  default     = {}
}

# ----------------------------------------------------------------------------
# Upgrade settings
# ----------------------------------------------------------------------------
variable "upgrade_settings" {
  description = "Surge upgrade settings for the node pool."
  type = object({
    max_surge                     = string
    drain_timeout_in_minutes      = optional(number)
    node_soak_duration_in_minutes = optional(number)
  })
  default = {
    max_surge = "33%"
  }
}

# ----------------------------------------------------------------------------
# Advanced node configuration (rarely needed, exposed for completeness)
# ----------------------------------------------------------------------------
variable "kubelet_config" {
  description = "Custom kubelet configuration for the nodes."
  type = object({
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
  })
  default = null
}

variable "linux_os_config" {
  description = "Custom Linux OS configuration for the nodes."
  type = object({
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
  })
  default = null
}

variable "node_network_profile" {
  description = "Per-node-pool network profile."
  type = object({
    node_public_ip_tags            = optional(map(string))
    application_security_group_ids = optional(list(string))
    allowed_host_ports = optional(list(object({
      port_start = optional(number)
      port_end   = optional(number)
      protocol   = optional(string)
    })), [])
  })
  default = null
}

variable "windows_profile" {
  description = "Windows-specific node pool profile."
  type = object({
    outbound_nat_enabled = optional(bool, true)
  })
  default = null
}

# ----------------------------------------------------------------------------
# Lifecycle
# ----------------------------------------------------------------------------
variable "ignore_node_count_changes" {
  description = "Ignore drift on node_count so the cluster autoscaler can own the pool size without fighting Terraform."
  type        = bool
  default     = true
}

variable "create_timeout" {
  description = "Timeout for node pool create."
  type        = string
  default     = "60m"
}

variable "update_timeout" {
  description = "Timeout for node pool update."
  type        = string
  default     = "60m"
}

variable "read_timeout" {
  description = "Timeout for node pool read."
  type        = string
  default     = "5m"
}

variable "delete_timeout" {
  description = "Timeout for node pool delete."
  type        = string
  default     = "60m"
}
