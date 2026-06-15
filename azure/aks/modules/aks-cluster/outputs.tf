output "id" {
  description = "Resource ID of the AKS cluster."
  value       = azurerm_kubernetes_cluster.this.id
}

output "name" {
  description = "Name of the AKS cluster."
  value       = azurerm_kubernetes_cluster.this.name
}

output "fqdn" {
  description = "FQDN of the API server (public clusters)."
  value       = azurerm_kubernetes_cluster.this.fqdn
}

output "private_fqdn" {
  description = "Private FQDN of the API server (private clusters)."
  value       = azurerm_kubernetes_cluster.this.private_fqdn
}

output "node_resource_group" {
  description = "Auto-generated resource group containing the cluster nodes."
  value       = azurerm_kubernetes_cluster.this.node_resource_group
}

output "node_resource_group_id" {
  description = "Resource ID of the node resource group."
  value       = azurerm_kubernetes_cluster.this.node_resource_group_id
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL (used to federate workload identities)."
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "kubelet_identity" {
  description = "Kubelet managed identity (object_id, client_id, user_assigned_identity_id)."
  value       = azurerm_kubernetes_cluster.this.kubelet_identity
}

output "cluster_identity" {
  description = "Control-plane managed identity block."
  value       = azurerm_kubernetes_cluster.this.identity
}

output "key_vault_secrets_provider_identity" {
  description = "Managed identity used by the Key Vault Secrets Provider add-on, if enabled."
  value       = try(azurerm_kubernetes_cluster.this.key_vault_secrets_provider[0].secret_identity, null)
}

output "kube_config" {
  description = "Structured kube config block (sensitive)."
  value       = azurerm_kubernetes_cluster.this.kube_config
  sensitive   = true
}

output "kube_config_raw" {
  description = "Raw kubeconfig for the cluster (sensitive)."
  value       = azurerm_kubernetes_cluster.this.kube_config_raw
  sensitive   = true
}

output "kube_admin_config" {
  description = "Structured admin kube config block, present when AAD RBAC with local admin is enabled (sensitive)."
  value       = azurerm_kubernetes_cluster.this.kube_admin_config
  sensitive   = true
}

output "host" {
  description = "Kubernetes API server endpoint (sensitive)."
  value       = try(azurerm_kubernetes_cluster.this.kube_config[0].host, null)
  sensitive   = true
}

output "client_certificate" {
  description = "Base64 client certificate for the cluster (sensitive)."
  value       = try(azurerm_kubernetes_cluster.this.kube_config[0].client_certificate, null)
  sensitive   = true
}

output "client_key" {
  description = "Base64 client key for the cluster (sensitive)."
  value       = try(azurerm_kubernetes_cluster.this.kube_config[0].client_key, null)
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64 cluster CA certificate (sensitive)."
  value       = try(azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate, null)
  sensitive   = true
}
