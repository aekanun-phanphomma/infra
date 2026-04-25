variable "resource_group_name" {
  description = "Name of the Azure Resource Group to create."
  type        = string
  default     = "rg-storage"
}

variable "location" {
  description = "Azure region where resources will be deployed."
  type        = string
  default     = "eastus"
}

variable "storage_account_name" {
  description = "Globally unique storage account name (3-24 chars, lowercase alphanumeric)."
  type        = string
}

variable "replication_type" {
  description = "Storage account replication type (LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS)."
  type        = string
  default     = "GRS"
}

variable "container_names" {
  description = "List of blob containers to create inside the storage account."
  type        = list(string)
  default     = ["data", "backups"]
}

variable "blob_soft_delete_days" {
  description = "Retention period in days for soft-deleted blobs."
  type        = number
  default     = 30
}

variable "container_soft_delete_days" {
  description = "Retention period in days for soft-deleted containers."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Map of tags to apply to all resources."
  type        = map(string)
  default     = {}
}
