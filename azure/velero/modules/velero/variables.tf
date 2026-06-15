###############################################################################
# velero module — variables
#
# This module wraps Velero (https://velero.io) for an Azure Kubernetes cluster.
# It provisions everything Velero needs on Azure and installs the Velero Helm
# chart wired for Microsoft Entra Workload Identity (no static secrets):
#
#   * a Storage Account + blob container as the BackupStorageLocation (BSL)
#   * a user-assigned managed identity Velero authenticates as
#   * a federated identity credential binding the Velero K8s service account
#     to that identity via the cluster OIDC issuer
#   * role assignments: blob data plane on the storage account, and snapshot
#     management on the resource group(s) that hold the cluster's disks
#   * the Velero Helm release (azure plugin + CSI + node-agent for file backups)
#
# What Velero then backs up: Kubernetes API objects, PersistentVolumeClaims /
# PersistentVolumes (CSI disk snapshots), Azure managed disks (snapshots), and
# file contents of any volume — including Azure Files — via File System Backup
# (kopia) run by the node-agent DaemonSet.
###############################################################################

# ----------------------------------------------------------------------------
# Placement / naming
# ----------------------------------------------------------------------------
variable "name_prefix" {
  description = "Prefix used for the managed identity and federated credential names."
  type        = string
  default     = "velero"
}

variable "location" {
  description = "Azure region for the storage account and managed identity."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that holds the Velero storage account and managed identity."
  type        = string
}

variable "subscription_id" {
  description = "Subscription ID Velero operates in. Used in the BSL/VSL config so the Azure plugin targets the right subscription."
  type        = string
}

variable "tags" {
  description = "Tags applied to every Azure resource created by this module."
  type        = map(string)
  default     = {}
}

# ----------------------------------------------------------------------------
# Backup storage (Storage Account + container = Velero BackupStorageLocation)
# ----------------------------------------------------------------------------
variable "storage_account_name" {
  description = "Globally unique Storage Account name (3-24 chars, lowercase letters and digits)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "storage_account_name must be 3-24 characters, lowercase letters and digits only."
  }
}

variable "container_name" {
  description = "Blob container that stores Velero backups (the BSL 'bucket')."
  type        = string
  default     = "velero"
}

variable "storage_replication_type" {
  description = "Storage Account replication: LRS, ZRS, GRS, GZRS, RAGRS, RAGZRS. Geo-redundant is recommended so backups survive a regional outage."
  type        = string
  default     = "GRS"

  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "GZRS", "RAGRS", "RAGZRS"], var.storage_replication_type)
    error_message = "storage_replication_type must be one of: LRS, ZRS, GRS, GZRS, RAGRS, RAGZRS."
  }
}

variable "storage_account_tier" {
  description = "Storage Account performance tier. Standard is correct for backup blobs."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.storage_account_tier)
    error_message = "storage_account_tier must be Standard or Premium."
  }
}

variable "blob_soft_delete_days" {
  description = "Retention window (days) for soft-deleted blobs. Guards against accidental/malicious backup deletion."
  type        = number
  default     = 30
}

variable "container_soft_delete_days" {
  description = "Retention window (days) for soft-deleted containers."
  type        = number
  default     = 30
}

variable "shared_access_key_enabled" {
  description = "Allow Storage Account shared-key auth. Keep false to force Entra ID (workload identity) auth only — Velero never needs the key."
  type        = bool
  default     = false
}

variable "public_network_access_enabled" {
  description = "Allow public network access to the Storage Account. Set false and supply network_rules to restrict to a private endpoint / known networks."
  type        = bool
  default     = true
}

variable "network_rules" {
  description = "Optional Storage Account network ACLs. default_action 'Deny' locks the account to the listed IPs and subnets."
  type = object({
    default_action             = optional(string, "Deny")
    bypass                     = optional(set(string), ["AzureServices"])
    ip_rules                   = optional(list(string), [])
    virtual_network_subnet_ids = optional(list(string), [])
  })
  default = null
}

# ----------------------------------------------------------------------------
# Identity / workload identity federation
# ----------------------------------------------------------------------------
variable "oidc_issuer_url" {
  description = "OIDC issuer URL of the AKS cluster (cluster output oidc_issuer_url). Required to federate the Velero service account to the managed identity."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace Velero is installed into."
  type        = string
  default     = "velero"
}

variable "service_account_name" {
  description = "Kubernetes service account Velero's server runs as. Must match the federated credential subject and the Helm serviceAccount."
  type        = string
  default     = "velero"
}

variable "federated_credential_audience" {
  description = "Audience for the federated identity credential. The Entra workload identity default."
  type        = list(string)
  default     = ["api://AzureADTokenExchange"]
}

# ----------------------------------------------------------------------------
# RBAC — snapshot permissions on the resource group(s) holding cluster disks
# ----------------------------------------------------------------------------
variable "snapshot_scope_ids" {
  description = "Resource group (or other) IDs where Velero must manage disk snapshots — typically the AKS node resource group (MC_*). The identity is granted snapshot_role on each."
  type        = list(string)
  default     = []
}

variable "snapshot_role" {
  description = "Built-in role granted on each snapshot_scope_ids entry. 'Contributor' matches the upstream Velero Azure guide; narrow it to a custom role for least privilege if your environment allows."
  type        = string
  default     = "Contributor"
}

variable "assign_blob_role" {
  description = "Grant the identity 'Storage Blob Data Contributor' on the backup storage account. Disable only if you assign blob access out of band."
  type        = bool
  default     = true
}

# ----------------------------------------------------------------------------
# Helm release — the Velero install itself
# ----------------------------------------------------------------------------
variable "install_velero" {
  description = "Install the Velero Helm release. Set false to provision only the Azure resources (e.g. first apply before the cluster API server is reachable)."
  type        = bool
  default     = true
}

variable "helm_chart_version" {
  description = "Version of the vmware-tanzu/velero Helm chart."
  type        = string
  default     = "8.0.0"
}

variable "helm_repository" {
  description = "Helm repository hosting the Velero chart."
  type        = string
  default     = "https://vmware-tanzu.github.io/helm-charts"
}

variable "velero_image_repository" {
  description = "Velero server image repository."
  type        = string
  default     = "velero/velero"
}

variable "velero_image_tag" {
  description = "Velero server image tag. Pin to a known-good release; null tracks the chart's appVersion."
  type        = string
  default     = "v1.15.0"
}

variable "azure_plugin_image" {
  description = "velero-plugin-for-microsoft-azure init-container image (repository:tag). Provides the Azure object store and volume snapshotter."
  type        = string
  default     = "velero/velero-plugin-for-microsoft-azure:v1.11.0"
}

variable "enable_csi" {
  description = "Enable the EnableCSI feature flag so Velero snapshots CSI-backed PVCs (Azure Disk CSI) via VolumeSnapshots."
  type        = bool
  default     = true
}

variable "deploy_node_agent" {
  description = "Deploy the node-agent DaemonSet for File System Backup (kopia). Required to back up file contents of volumes such as Azure Files."
  type        = bool
  default     = true
}

variable "uploader_type" {
  description = "File System Backup uploader: kopia (recommended) or restic."
  type        = string
  default     = "kopia"

  validation {
    condition     = contains(["kopia", "restic"], var.uploader_type)
    error_message = "uploader_type must be kopia or restic."
  }
}

variable "default_volumes_to_fs_backup" {
  description = "Back up all pod volumes with File System Backup by default. Leave false to prefer CSI/disk snapshots and opt specific volumes into FSB."
  type        = bool
  default     = false
}

variable "server_resources" {
  description = "Resource requests/limits for the Velero server container."
  type = object({
    requests = optional(map(string), { cpu = "500m", memory = "512Mi" })
    limits   = optional(map(string), { cpu = "1", memory = "1Gi" })
  })
  default = {}
}

variable "node_agent_resources" {
  description = "Resource requests/limits for the node-agent DaemonSet."
  type = object({
    requests = optional(map(string), { cpu = "500m", memory = "512Mi" })
    limits   = optional(map(string), { cpu = "1", memory = "1Gi" })
  })
  default = {}
}

variable "backup_schedules" {
  description = "Velero backup Schedules rendered into the chart. Map key is the schedule name; cron is standard 5-field. Drives recurring backups of cluster objects + volumes."
  type = map(object({
    schedule                     = string
    disabled                     = optional(bool, false)
    paused                       = optional(bool, false)
    ttl                          = optional(string, "720h")
    storage_location             = optional(string, "default")
    included_namespaces          = optional(list(string), ["*"])
    excluded_namespaces          = optional(list(string), [])
    included_resources           = optional(list(string), [])
    excluded_resources           = optional(list(string), [])
    snapshot_volumes             = optional(bool, true)
    default_volumes_to_fs_backup = optional(bool, false)
    include_cluster_resources    = optional(bool, true)
    labels                       = optional(map(string), {})
  }))
  default = {}
}

variable "helm_timeout" {
  description = "Timeout (seconds) for the Velero Helm release."
  type        = number
  default     = 600
}

variable "additional_helm_values" {
  description = "Extra Helm values merged last (highest precedence), as a YAML string. Use for any chart key this module does not surface."
  type        = string
  default     = ""
}
