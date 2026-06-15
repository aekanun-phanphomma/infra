output "identity_id" {
  description = "Resource ID of the Velero user-assigned managed identity."
  value       = azurerm_user_assigned_identity.velero.id
}

output "identity_client_id" {
  description = "Client ID of the Velero managed identity (used in the service account annotation)."
  value       = azurerm_user_assigned_identity.velero.client_id
}

output "identity_principal_id" {
  description = "Principal (object) ID of the Velero managed identity, used in role assignments."
  value       = azurerm_user_assigned_identity.velero.principal_id
}

output "storage_account_id" {
  description = "Resource ID of the backup storage account."
  value       = azurerm_storage_account.this.id
}

output "storage_account_name" {
  description = "Name of the backup storage account."
  value       = azurerm_storage_account.this.name
}

output "container_name" {
  description = "Blob container holding Velero backups (the BSL bucket)."
  value       = azurerm_storage_container.this.name
}

output "namespace" {
  description = "Namespace Velero is installed into."
  value       = var.namespace
}

output "service_account_name" {
  description = "Service account Velero's server runs as."
  value       = var.service_account_name
}

output "federated_credential_subject" {
  description = "Subject of the federated identity credential bound to the Velero service account."
  value       = azurerm_federated_identity_credential.velero.subject
}

output "helm_release_name" {
  description = "Name of the Velero Helm release, or null when install_velero = false."
  value       = var.install_velero ? helm_release.velero[0].name : null
}
