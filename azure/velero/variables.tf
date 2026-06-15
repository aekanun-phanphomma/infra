###############################################################################
# Root variables — the opinionated, production-leaning surface for deploying
# Velero against an EXISTING AKS cluster. The cluster's OIDC issuer, node
# resource group and subscription are discovered from the cluster itself, so the
# day-to-day inputs are just: which cluster, and where to keep the backups.
###############################################################################

# ----------------------------------------------------------------------------
# Target cluster (existing)
# ----------------------------------------------------------------------------
variable "aks_cluster_name" {
  description = "Name of the existing AKS cluster Velero will protect."
  type        = string
}

variable "aks_resource_group_name" {
  description = "Resource group containing the existing AKS cluster."
  type        = string
}

# ----------------------------------------------------------------------------
# Velero resources placement / naming
# ----------------------------------------------------------------------------
variable "resource_group_name" {
  description = "Resource group that holds Velero's storage account and managed identity. Created by this configuration."
  type        = string
  default     = "rg-velero-prod"
}

variable "location" {
  description = "Azure region for the Velero storage account and identity. Should match (or be paired with) the cluster region."
  type        = string
  default     = "southeastasia"
}

variable "storage_account_name" {
  description = "Globally unique Storage Account name for backups (3-24 lowercase alphanumerics)."
  type        = string
}

variable "container_name" {
  description = "Blob container that stores Velero backups."
  type        = string
  default     = "velero"
}

variable "tags" {
  description = "Tags applied to every Azure resource."
  type        = map(string)
  default = {
    environment = "production"
    managed_by  = "terraform"
    workload    = "velero-backup"
  }
}

# ----------------------------------------------------------------------------
# Storage hardening
# ----------------------------------------------------------------------------
variable "storage_replication_type" {
  description = "Backup storage replication. Geo-redundant (GRS/GZRS) keeps backups available through a regional outage."
  type        = string
  default     = "GRS"
}

variable "shared_access_key_enabled" {
  description = "Allow storage shared-key auth. Keep false — Velero uses workload identity."
  type        = bool
  default     = false
}

variable "public_network_access_enabled" {
  description = "Allow public network access to the backup storage account."
  type        = bool
  default     = true
}

variable "network_rules" {
  description = "Optional storage network ACLs to lock the backup account to known networks / a private endpoint."
  type = object({
    default_action             = optional(string, "Deny")
    bypass                     = optional(set(string), ["AzureServices"])
    ip_rules                   = optional(list(string), [])
    virtual_network_subnet_ids = optional(list(string), [])
  })
  default = null
}

# ----------------------------------------------------------------------------
# RBAC
# ----------------------------------------------------------------------------
variable "extra_snapshot_scope_ids" {
  description = "Additional resource group IDs (beyond the AKS node RG) where Velero must manage disk snapshots — e.g. RGs holding statically-provisioned data disks."
  type        = list(string)
  default     = []
}

variable "snapshot_role" {
  description = "Built-in role granted to Velero on each snapshot scope. Contributor matches the upstream guide."
  type        = string
  default     = "Contributor"
}

# ----------------------------------------------------------------------------
# Velero install
# ----------------------------------------------------------------------------
variable "install_velero" {
  description = "Install the Velero Helm release. Set false on the first apply if the runner cannot reach the cluster API server yet, then re-enable."
  type        = bool
  default     = true
}

variable "namespace" {
  description = "Namespace Velero is installed into."
  type        = string
  default     = "velero"
}

variable "helm_chart_version" {
  description = "Version of the vmware-tanzu/velero Helm chart."
  type        = string
  default     = "8.0.0"
}

variable "velero_image_tag" {
  description = "Velero server image tag."
  type        = string
  default     = "v1.15.0"
}

variable "azure_plugin_image" {
  description = "velero-plugin-for-microsoft-azure init-container image (repository:tag)."
  type        = string
  default     = "velero/velero-plugin-for-microsoft-azure:v1.11.0"
}

variable "deploy_node_agent" {
  description = "Deploy the node-agent DaemonSet for File System Backup (kopia) — required to back up file contents of volumes such as Azure Files."
  type        = bool
  default     = true
}

variable "default_volumes_to_fs_backup" {
  description = "Use File System Backup for all pod volumes by default. Leave false to prefer CSI/disk snapshots."
  type        = bool
  default     = false
}

variable "backup_schedules" {
  description = "Velero backup Schedules. Defaults give a daily snapshot-based backup of all namespaces (30-day TTL) and a weekly file-level backup (90-day TTL)."
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
  default = {
    # Daily backup of everything, using CSI/disk snapshots for volumes. 30 days.
    daily-snapshots = {
      schedule         = "0 1 * * *"
      ttl              = "720h"
      snapshot_volumes = true
    }
    # Weekly file-level backup of everything via kopia. 90 days. Belt and
    # braces against snapshot-incompatible volumes (e.g. Azure Files).
    weekly-fs-backup = {
      schedule                     = "0 3 * * 0"
      ttl                          = "2160h"
      snapshot_volumes             = false
      default_volumes_to_fs_backup = true
    }
  }
}
