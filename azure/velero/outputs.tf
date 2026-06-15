output "resource_group_name" {
  description = "Resource group holding the Velero storage account and identity."
  value       = azurerm_resource_group.this.name
}

output "identity_client_id" {
  description = "Client ID of the Velero managed identity."
  value       = module.velero.identity_client_id
}

output "identity_principal_id" {
  description = "Principal (object) ID of the Velero managed identity."
  value       = module.velero.identity_principal_id
}

output "storage_account_name" {
  description = "Backup storage account name."
  value       = module.velero.storage_account_name
}

output "backup_container_name" {
  description = "Blob container holding Velero backups."
  value       = module.velero.container_name
}

output "namespace" {
  description = "Namespace Velero is installed into."
  value       = module.velero.namespace
}

output "federated_credential_subject" {
  description = "Federated credential subject bound to the Velero service account."
  value       = module.velero.federated_credential_subject
}

output "node_resource_group_id" {
  description = "AKS node resource group granted snapshot permissions."
  value       = local.node_resource_group_id
}
