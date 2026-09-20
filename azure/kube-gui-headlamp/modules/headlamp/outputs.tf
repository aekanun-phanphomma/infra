################################################################################
# Outputs
#
# No credential is exported. The OIDC client secret is deliberately absent, and
# only the Secret's name is published so callers can reference it.
################################################################################

locals {
  # Mirrors the chart's fullname helper: a release name that already contains the
  # chart name is used as-is, otherwise the chart name is appended. This is how
  # the Service, Deployment and Ingress objects are named.
  headlamp_fullname = substr(
    strcontains(var.headlamp_release_name, var.headlamp_chart_name) ? var.headlamp_release_name : "${var.headlamp_release_name}-${var.headlamp_chart_name}",
    0,
    63,
  )
}

output "namespace" {
  description = "Namespace Headlamp is deployed into."
  value       = local.namespace
}

output "release_name" {
  description = "Helm release name."
  value       = helm_release.headlamp.name
}

output "release_status" {
  description = "Status of the Helm release."
  value       = helm_release.headlamp.status
}

output "chart_version" {
  description = "Headlamp chart version that is deployed."
  value       = local.effective_chart_version
}

output "chart_source" {
  description = "Where the chart came from: the vendored copy inside the module, or the remote repository."
  value       = var.headlamp_use_local_chart ? "local: ${local.local_chart_path}" : "remote: ${var.headlamp_chart_repository}"
}

output "app_version" {
  description = "Headlamp application version behind the deployed chart."
  value       = one(helm_release.headlamp.metadata[*].app_version)
}

output "service_name" {
  description = "Name of the Headlamp Service."
  value       = local.headlamp_fullname
}

output "service_port" {
  description = "Port exposed by the Headlamp Service."
  value       = var.service_port
}

output "service_type" {
  description = "Type of the Headlamp Service."
  value       = var.service_type
}

output "port_forward_command" {
  description = "Ready-to-run port-forward command for reaching Headlamp without an ingress."
  value       = "kubectl port-forward --namespace ${local.namespace} svc/${local.headlamp_fullname} 8000:${var.service_port}"
}

output "ingress_enabled" {
  description = "Whether an Ingress was created for Headlamp."
  value       = var.ingress_enabled
}

output "ingress_hostname" {
  description = "Hostname on the Headlamp Ingress, or null when ingress is disabled."
  value       = var.ingress_enabled ? var.ingress_host : null
}

output "headlamp_url" {
  description = "Browser URL for Headlamp, or null when no ingress is configured."
  value       = var.ingress_enabled ? format("%s://%s%s", var.ingress_tls_enabled ? "https" : "http", var.ingress_host, var.base_url) : null
}

################################################################################
# OIDC status. Configuration state only, never credential material.
################################################################################

output "oidc_enabled" {
  description = "Whether Headlamp is configured for OIDC sign-in."
  value       = var.oidc_enabled
}

output "oidc_redirect_url" {
  description = "Callback URL Headlamp uses. This exact value must be registered as a redirect URI on the Entra App Registration."
  value       = var.oidc_enabled ? local.oidc_redirect_url : null
}

output "oidc_secret_name" {
  description = "Name of the Kubernetes Secret holding the OIDC credentials. The name only, never the contents."
  value       = var.oidc_enabled ? local.oidc_secret_name : null
}

output "oidc_secret_managed_by_terraform" {
  description = "True when Terraform created the OIDC Secret, which means the client secret is present in Terraform state."
  value       = local.create_oidc_secret
}

output "headlamp_service_account_has_cluster_role_binding" {
  description = "Whether Headlamp's own ServiceAccount was granted a cluster-wide role. False is the hardened default."
  value       = var.headlamp_cluster_role_binding_enabled
}

################################################################################
# RBAC inventory
################################################################################

output "cluster_role_names" {
  description = "ClusterRoles created by this module, keyed by role definition name."
  value       = { for k, v in kubernetes_cluster_role_v1.managed : k => v.metadata[0].name }
}

output "namespace_role_names" {
  description = "Namespace-scoped Roles created by this module, keyed by namespace_roles key."
  value       = { for k, v in kubernetes_role_v1.namespaced : k => "${v.metadata[0].namespace}/${v.metadata[0].name}" }
}

output "cluster_role_binding_names" {
  description = "ClusterRoleBindings created by this module, keyed by group."
  value       = { for k, v in kubernetes_cluster_role_binding_v1.group : k => v.metadata[0].name }
}

output "role_binding_names" {
  description = "RoleBindings created by this module, keyed by group and namespace."
  value       = { for k, v in kubernetes_role_binding_v1.group : k => "${v.metadata[0].namespace}/${v.metadata[0].name}" }
}

output "access_matrix" {
  description = "Effective access granted per group: the object ID authorised, the role bound, and where it applies. Useful as an audit artefact and as input to access reviews."
  value = {
    for k, g in var.rbac_groups : k => {
      object_id  = g.object_id
      scope      = g.scope
      role_kind  = local.group_role_ref[k].kind
      role_name  = local.group_role_ref[k].name
      namespaces = g.scope == "cluster" ? ["*"] : g.namespaces
    }
  }
}
