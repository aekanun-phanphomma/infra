# azure/storage-blob

Deploys an Azure Storage Account with one or more private Blob containers, hardened with:
- HTTPS-only traffic and TLS 1.2 minimum
- No public blob access
- Blob versioning enabled
- Soft-delete for blobs and containers
- Configurable replication type (GRS by default)

## Usage

```hcl
module "storage" {
  source = "./infra/azure/storage-blob"

  resource_group_name        = "rg-data-prod"
  location                   = "eastus"
  storage_account_name       = "mystorageacct0042"
  replication_type           = "GRS"
  container_names            = ["raw", "processed", "backups"]
  blob_soft_delete_days      = 30
  container_soft_delete_days = 30

  tags = {
    environment = "production"
    team        = "data"
  }
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| resource_group_name | string | `"rg-storage"` | Name of the Azure Resource Group to create. |
| location | string | `"eastus"` | Azure region where resources will be deployed. |
| storage_account_name | string | *(required)* | Globally unique storage account name (3-24 chars, lowercase alphanumeric). |
| replication_type | string | `"GRS"` | Storage account replication type (LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS). |
| container_names | list(string) | `["data","backups"]` | List of blob containers to create inside the storage account. |
| blob_soft_delete_days | number | `30` | Retention period in days for soft-deleted blobs. |
| container_soft_delete_days | number | `30` | Retention period in days for soft-deleted containers. |
| tags | map(string) | `{}` | Map of tags to apply to all resources. |

## Outputs

| Name | Description |
|------|-------------|
| storage_account_id | Resource ID of the storage account. |
| storage_account_name | Name of the storage account. |
| primary_blob_endpoint | Primary blob service endpoint URL. |
| container_names | List of blob container names created. |
