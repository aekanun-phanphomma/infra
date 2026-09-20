################################################################################
# Labels
#
# Only the standard app.kubernetes.io labels are applied by default. The Helm
# chart labels its own objects; these labels cover the objects this module
# creates directly.
################################################################################

locals {
  common_labels = merge(
    {
      "app.kubernetes.io/name"       = "headlamp"
      "app.kubernetes.io/instance"   = var.headlamp_release_name
      "app.kubernetes.io/managed-by" = "Terraform"
    },
    var.labels,
  )

  namespace_labels = merge(local.common_labels, {
    "app.kubernetes.io/component" = "namespace"
  })

  rbac_labels = merge(local.common_labels, {
    "app.kubernetes.io/component" = "rbac"
  })

  secret_labels = merge(local.common_labels, {
    "app.kubernetes.io/component" = "oidc"
  })
}

################################################################################
# Chart source
#
# Two ways to obtain the chart:
#
#   local (default)  the chart vendored at modules/headlamp/charts. Resolved
#                    from path.module, so it works regardless of which directory
#                    Terraform is run from, and needs no network egress.
#   remote           downloaded from headlamp_chart_repository at plan time.
#
# In local mode the `version` argument is left unset, because Helm reads the
# version from the chart itself. The declared version is not thrown away though:
# it is compared against Chart.yaml in a precondition, so the vendored chart and
# the code cannot drift apart unnoticed.
################################################################################

locals {
  local_chart_path = abspath("${path.module}/charts")

  local_chart_version = try(
    yamldecode(file("${path.module}/charts/Chart.yaml")).version,
    null,
  )

  chart_reference  = var.headlamp_use_local_chart ? local.local_chart_path : var.headlamp_chart_name
  chart_repository = var.headlamp_use_local_chart ? null : var.headlamp_chart_repository
  chart_version    = var.headlamp_use_local_chart ? null : var.headlamp_chart_version

  effective_chart_version = var.headlamp_use_local_chart ? local.local_chart_version : var.headlamp_chart_version
}

################################################################################
# OIDC
#
# Two supported secret strategies, both of which use the chart's externalSecret
# path so that credentials never travel through Helm values:
#
#   1. oidc_existing_secret_name set  -> the module creates nothing and points
#      the chart at a Secret managed outside Terraform. Recommended.
#   2. oidc_client_secret set         -> the module creates the Secret. The
#      value then lives in Terraform state.
#
# Everything that is not a credential (callback URL, scopes, validator settings)
# is passed as plain pod environment variables. The chart's externalSecret branch
# only emits the matching command-line flags when it can see these values, so
# they must be supplied here rather than under config.oidc.
################################################################################

locals {
  create_oidc_secret = var.oidc_enabled && var.oidc_existing_secret_name == null

  oidc_secret_name = var.oidc_enabled ? coalesce(
    var.oidc_existing_secret_name,
    "${var.name_prefix}-oidc",
  ) : ""

  # Derive the callback URL from the ingress host when it was not given
  # explicitly. Empty means "not resolvable", which the precondition rejects.
  oidc_redirect_url_derived = var.ingress_enabled && var.ingress_host != null ? format(
    "%s://%s%s/oidc-callback",
    var.ingress_tls_enabled ? "https" : "http",
    var.ingress_host,
    var.base_url,
  ) : ""

  oidc_redirect_url = var.oidc_redirect_url != null ? var.oidc_redirect_url : local.oidc_redirect_url_derived

  oidc_env = var.oidc_enabled ? concat(
    [
      { name = "OIDC_SCOPES", value = join(",", var.oidc_scopes) },
      { name = "OIDC_CALLBACK_URL", value = local.oidc_redirect_url },
      { name = "OIDC_USE_ACCESS_TOKEN", value = tostring(var.oidc_use_access_token) },
    ],
    var.oidc_use_pkce ? [{ name = "OIDC_USE_PKCE", value = "true" }] : [],
    var.oidc_validator_client_id != null ? [{ name = "OIDC_VALIDATOR_CLIENT_ID", value = var.oidc_validator_client_id }] : [],
    var.oidc_validator_issuer_url != null ? [{ name = "OIDC_VALIDATOR_ISSUER_URL", value = var.oidc_validator_issuer_url }] : [],
  ) : []

  oidc_chart_config = {
    # Never let the chart build the Secret from values: that would place the
    # client secret into the Helm release data stored in the cluster.
    secret = {
      create = false
    }

    externalSecret = {
      enabled = var.oidc_enabled
      name    = local.oidc_secret_name
      # Tells the chart to emit -oidc-scopes. The value itself arrives through
      # the OIDC_SCOPES environment variable above rather than from the Secret.
      hasScopes = var.oidc_enabled
    }
  }
}

################################################################################
# Helm values
#
# Built as a Terraform object and rendered with yamlencode, then handed to Helm
# as a single values document. Caller-supplied documents are appended after it,
# so they win on conflict.
################################################################################

locals {
  helm_values_generated = {
    replicaCount = var.replica_count

    image = {
      pullPolicy = var.image_pull_policy
    }

    serviceAccount = {
      create      = true
      name        = var.service_account_name != null ? var.service_account_name : ""
      annotations = var.service_account_annotations
    }

    automountServiceAccountToken = true

    # See the README section on the Headlamp service account. Enabling this
    # grants the Headlamp pod itself standing cluster-wide permissions.
    clusterRoleBinding = {
      create          = var.headlamp_cluster_role_binding_enabled
      clusterRoleName = var.headlamp_cluster_role_binding_role_name
    }

    config = {
      inCluster                    = true
      baseURL                      = var.base_url
      sessionTTL                   = var.session_ttl_seconds
      unsafeUseServiceAccountToken = false
      enableHelm                   = false
      oidc                         = local.oidc_chart_config
    }

    env = local.oidc_env

    podAnnotations     = var.pod_annotations
    podLabels          = var.pod_labels
    podSecurityContext = var.pod_security_context
    securityContext    = var.container_security_context

    service = {
      type        = var.service_type
      port        = var.service_port
      annotations = var.service_annotations
    }

    # Always the same shape so the object type stays consistent; the chart only
    # renders an Ingress when enabled is true.
    ingress = {
      enabled          = var.ingress_enabled
      ingressClassName = var.ingress_class_name != null ? var.ingress_class_name : ""
      annotations      = var.ingress_annotations
      labels           = var.ingress_labels

      hosts = var.ingress_enabled ? [
        {
          host  = var.ingress_host
          paths = [for p in var.ingress_paths : { path = p.path, type = p.type }]
        },
      ] : []

      tls = var.ingress_enabled && var.ingress_tls_enabled ? [
        {
          secretName = var.ingress_tls_secret_name
          hosts      = [var.ingress_host]
        },
      ] : []
    }

    resources = {
      requests = {
        cpu    = var.resources.requests.cpu
        memory = var.resources.requests.memory
      }
      limits = {
        cpu    = var.resources.limits.cpu
        memory = var.resources.limits.memory
      }
    }

    probes = {
      scheme = var.probes.scheme
      livenessProbe = {
        initialDelaySeconds = var.probes.liveness.initialDelaySeconds
        periodSeconds       = var.probes.liveness.periodSeconds
        timeoutSeconds      = var.probes.liveness.timeoutSeconds
        failureThreshold    = var.probes.liveness.failureThreshold
      }
      readinessProbe = {
        initialDelaySeconds = var.probes.readiness.initialDelaySeconds
        periodSeconds       = var.probes.readiness.periodSeconds
        timeoutSeconds      = var.probes.readiness.timeoutSeconds
        successThreshold    = var.probes.readiness.successThreshold
        failureThreshold    = var.probes.readiness.failureThreshold
      }
    }

    podDisruptionBudget = {
      enabled      = var.pod_disruption_budget_enabled
      minAvailable = var.pod_disruption_budget_min_available
    }

    nodeSelector = var.node_selector
    tolerations  = var.tolerations
  }

  helm_values = concat(
    [yamlencode(local.helm_values_generated)],
    var.headlamp_extra_values,
  )
}

################################################################################
# RBAC: role catalogue
#
# custom_roles are merged into the built-in definitions so that a group can
# reference either by the same "role" key. Only the roles a group actually uses
# are created, which keeps the cluster free of unused ClusterRoles.
################################################################################

locals {
  all_role_definitions = merge(var.rbac_role_definitions, var.custom_roles)

  referenced_role_keys = var.rbac_enabled ? toset(compact([
    for k, g in var.rbac_groups : g.role
  ])) : toset([])

  managed_cluster_roles = {
    for key in local.referenced_role_keys : key => local.all_role_definitions[key]
  }

  cluster_role_names = {
    for key, _ in local.all_role_definitions : key => "${var.name_prefix}-rbac-${key}"
  }

  managed_namespace_roles = var.rbac_enabled ? var.namespace_roles : {}

  namespace_role_names = {
    for key, _ in var.namespace_roles : key => "${var.name_prefix}-role-${key}"
  }

  # Resolve each group to the single role reference it binds to.
  group_role_ref = {
    for k, g in var.rbac_groups : k => (
      g.role != null ? {
        kind = "ClusterRole"
        name = local.cluster_role_names[g.role]
        } : g.cluster_role_name != null ? {
        kind = "ClusterRole"
        name = g.cluster_role_name
        } : {
        kind = "Role"
        name = local.namespace_role_names[g.namespace_role_name]
      }
    )
  }
}

################################################################################
# RBAC: bindings
#
# Cluster-scoped groups produce one ClusterRoleBinding each. Namespace-scoped
# groups are flattened into one RoleBinding per (group, namespace) pair. Keys are
# built from the group key and namespace name, both of which are stable inputs,
# so no binding depends on list ordering.
################################################################################

locals {
  cluster_bindings = var.rbac_enabled ? {
    for k, g in var.rbac_groups : k => {
      group_key = k
      object_id = g.object_id
      role_kind = local.group_role_ref[k].kind
      role_name = local.group_role_ref[k].name
      name      = "${var.name_prefix}-crb-${k}"
    }
    if g.scope == "cluster"
  } : {}

  namespace_binding_list = var.rbac_enabled ? flatten([
    for k, g in var.rbac_groups : [
      for ns in g.namespaces : {
        key                 = "${k}/${ns}"
        group_key           = k
        namespace           = ns
        object_id           = g.object_id
        role_kind           = local.group_role_ref[k].kind
        role_name           = local.group_role_ref[k].name
        namespace_role_name = g.namespace_role_name
        name                = "${var.name_prefix}-rb-${ns}-${k}"
      }
    ] if g.scope == "namespace"
  ]) : []

  namespace_bindings = {
    for b in local.namespace_binding_list : b.key => b
  }
}
