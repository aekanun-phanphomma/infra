output "headlamp_url" {
  description = "Browser URL for Headlamp."
  value       = module.headlamp.headlamp_url
}

output "oidc_redirect_url" {
  description = "Register this exact value as a redirect URI on the Entra App Registration, or sign-in fails with AADSTS50011."
  value       = module.headlamp.oidc_redirect_url
}

output "namespace" {
  description = "Namespace Headlamp runs in."
  value       = module.headlamp.namespace
}

output "service_name" {
  description = "Headlamp Service name."
  value       = module.headlamp.service_name
}

output "port_forward_command" {
  description = "Reach Headlamp without going through the ingress, useful while the DNS record or certificate is still pending."
  value       = module.headlamp.port_forward_command
}

output "oidc_secret_managed_by_terraform" {
  description = "True means the client secret is present in this configuration's Terraform state."
  value       = module.headlamp.oidc_secret_managed_by_terraform
}

output "headlamp_service_account_has_cluster_role_binding" {
  description = "Expected to be false: Headlamp's own ServiceAccount holds no cluster-wide permissions."
  value       = module.headlamp.headlamp_service_account_has_cluster_role_binding
}

output "access_matrix" {
  description = "Effective access per Entra group. Useful as evidence during an access review."
  value       = module.headlamp.access_matrix
}

output "cluster_role_binding_names" {
  description = "ClusterRoleBindings created for cluster-scoped groups."
  value       = module.headlamp.cluster_role_binding_names
}

output "role_binding_names" {
  description = "RoleBindings created for namespace-scoped groups."
  value       = module.headlamp.role_binding_names
}
