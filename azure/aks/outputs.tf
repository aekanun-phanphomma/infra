output "cluster_id" {
  description = "Resource ID of the AKS cluster."
  value       = module.aks_cluster.id
}

output "cluster_name" {
  description = "Name of the AKS cluster."
  value       = module.aks_cluster.name
}

output "cluster_private_fqdn" {
  description = "Private FQDN of the API server."
  value       = module.aks_cluster.private_fqdn
}

output "node_resource_group" {
  description = "Auto-generated resource group holding the cluster nodes."
  value       = module.aks_cluster.node_resource_group
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for federating workload identities."
  value       = module.aks_cluster.oidc_issuer_url
}

output "kubelet_identity_object_id" {
  description = "Object ID of the kubelet managed identity (grant ACR pull, etc.)."
  value       = try(module.aks_cluster.kubelet_identity[0].object_id, null)
}

output "key_vault_secrets_provider_identity" {
  description = "Identity used by the Key Vault Secrets Provider add-on."
  value       = module.aks_cluster.key_vault_secrets_provider_identity
}

output "user_node_pool_id" {
  description = "Resource ID of the user node pool."
  value       = module.aks_nodepool_user.id
}

output "disk_encryption_set_id" {
  description = "Disk Encryption Set ID used for CMK disk encryption (null when disabled)."
  value       = local.disk_encryption_set_id
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace backing Container Insights."
  value       = local.log_analytics_workspace_id
}

output "kube_config_raw" {
  description = "Raw kubeconfig (sensitive). Prefer `az aks get-credentials` for AAD clusters."
  value       = module.aks_cluster.kube_config_raw
  sensitive   = true
}
