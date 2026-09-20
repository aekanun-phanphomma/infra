################################################################################
# RBAC
#
# Kept in its own file because authorisation is a separate concern from the
# Headlamp deployment: these objects govern what every signed-in user may do
# against the Kubernetes API, and they stay meaningful even if Headlamp is
# replaced by another client. main.tf owns the GUI; this file owns access.
#
# Subjects are Microsoft Entra group object IDs. AKS places group object IDs in
# the token's groups claim, so an object ID is the identity the API server
# authorises against. Display names are not.
################################################################################

################################################################################
# ClusterRoles for the module-managed permission sets
#
# One ClusterRole per role key that a group actually references. A ClusterRole is
# used even for namespace-scoped access: the same permission set is then bound
# into each namespace with a RoleBinding, which keeps one definition instead of
# one copy per namespace.
################################################################################

resource "kubernetes_cluster_role_v1" "managed" {
  for_each = local.managed_cluster_roles

  metadata {
    name        = local.cluster_role_names[each.key]
    labels      = merge(local.rbac_labels, { "headlamp.dev/role" = each.key })
    annotations = var.annotations
  }

  dynamic "rule" {
    for_each = each.value.rules

    content {
      api_groups        = rule.value.api_groups
      resources         = rule.value.resources
      verbs             = rule.value.verbs
      resource_names    = length(rule.value.resource_names) > 0 ? rule.value.resource_names : null
      non_resource_urls = length(rule.value.non_resource_urls) > 0 ? rule.value.non_resource_urls : null
    }
  }
}

################################################################################
# Namespace-scoped Roles
#
# For permission sets that should not exist as cluster-wide objects at all.
################################################################################

resource "kubernetes_role_v1" "namespaced" {
  for_each = local.managed_namespace_roles

  metadata {
    name        = local.namespace_role_names[each.key]
    namespace   = each.value.namespace
    labels      = merge(local.rbac_labels, { "headlamp.dev/role" = each.key })
    annotations = var.annotations
  }

  dynamic "rule" {
    for_each = each.value.rules

    content {
      api_groups     = rule.value.api_groups
      resources      = rule.value.resources
      verbs          = rule.value.verbs
      resource_names = length(rule.value.resource_names) > 0 ? rule.value.resource_names : null
    }
  }
}

################################################################################
# Cluster-wide bindings
#
# One ClusterRoleBinding per group with cluster scope. This grants the role in
# every namespace, including namespaces created later.
################################################################################

resource "kubernetes_cluster_role_binding_v1" "group" {
  for_each = local.cluster_bindings

  metadata {
    name        = each.value.name
    labels      = merge(local.rbac_labels, { "headlamp.dev/group" = each.key })
    annotations = var.annotations
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"

    # Referencing the resource when the role is module-managed is what orders
    # the ClusterRole before its binding.
    name = var.rbac_groups[each.value.group_key].role != null ? (
      kubernetes_cluster_role_v1.managed[var.rbac_groups[each.value.group_key].role].metadata[0].name
    ) : each.value.role_name
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Group"
    name      = each.value.object_id
  }

  lifecycle {
    precondition {
      condition     = length(each.value.name) <= 253
      error_message = "The generated ClusterRoleBinding name exceeds the 253 character Kubernetes limit. Shorten name_prefix or the group key."
    }
  }
}

################################################################################
# Namespace-scoped bindings
#
# One RoleBinding per (group, namespace) pair. A ClusterRoleBinding is never used
# here: it would grant the role in every namespace and defeat the isolation the
# namespace scope is asking for.
################################################################################

resource "kubernetes_role_binding_v1" "group" {
  for_each = local.namespace_bindings

  metadata {
    name        = each.value.name
    namespace   = each.value.namespace
    labels      = merge(local.rbac_labels, { "headlamp.dev/group" = each.value.group_key })
    annotations = var.annotations
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = each.value.role_kind

    name = each.value.role_kind == "Role" ? (
      kubernetes_role_v1.namespaced[each.value.namespace_role_name].metadata[0].name
      ) : var.rbac_groups[each.value.group_key].role != null ? (
      kubernetes_cluster_role_v1.managed[var.rbac_groups[each.value.group_key].role].metadata[0].name
    ) : each.value.role_name
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Group"
    name      = each.value.object_id
  }

  lifecycle {
    precondition {
      condition     = length(each.value.name) <= 253
      error_message = "The generated RoleBinding name exceeds the 253 character Kubernetes limit. Shorten name_prefix, the namespace or the group key."
    }
    precondition {
      condition = (
        each.value.role_kind != "Role" ||
        var.namespace_roles[each.value.namespace_role_name].namespace == each.value.namespace
      )
      error_message = "A group bound to a namespace_role_name may only list the namespace that Role lives in. A RoleBinding cannot reference a Role in another namespace."
    }
  }
}
