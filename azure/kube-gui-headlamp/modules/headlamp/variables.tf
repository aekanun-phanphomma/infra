################################################################################
# Naming and namespace
################################################################################

variable "name_prefix" {
  description = <<-EOT
    Prefix used to build deterministic names for every Kubernetes object this
    module creates directly (OIDC Secret, ClusterRoles, Roles and bindings).
    It does NOT rename the objects created by the Helm chart itself; those are
    named by the chart from the release name.
  EOT
  type        = string
  default     = "headlamp"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.name_prefix)) && length(var.name_prefix) <= 40
    error_message = "name_prefix must be a lowercase RFC 1123 label of at most 40 characters."
  }
}

variable "headlamp_namespace" {
  description = "Namespace that Headlamp is deployed into."
  type        = string
  default     = "headlamp"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.headlamp_namespace)) && length(var.headlamp_namespace) <= 63
    error_message = "headlamp_namespace must be a valid RFC 1123 DNS label (lowercase alphanumeric and '-', max 63 characters)."
  }
}

variable "create_namespace" {
  description = <<-EOT
    Create the Headlamp namespace with the Kubernetes provider.

    Set to false when the namespace is created elsewhere, for example by a
    landing-zone module or by GitOps. The Helm release is deliberately not
    allowed to create the namespace, so namespace ownership stays explicit and
    the namespace survives a Helm uninstall.
  EOT
  type        = bool
  default     = true
}

variable "labels" {
  description = "Extra labels merged into every object this module creates directly. The standard app.kubernetes.io labels are always applied."
  type        = map(string)
  default     = {}
}

variable "annotations" {
  description = "Extra annotations merged into every object this module creates directly."
  type        = map(string)
  default     = {}
}

################################################################################
# Helm release
################################################################################

variable "headlamp_release_name" {
  description = "Helm release name. Helm limits release names to 53 characters."
  type        = string
  default     = "headlamp"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.headlamp_release_name)) && length(var.headlamp_release_name) <= 53
    error_message = "headlamp_release_name must be a lowercase RFC 1123 label of at most 53 characters."
  }
}

variable "headlamp_use_local_chart" {
  description = <<-EOT
    Install from the chart vendored inside this module at charts/, instead of
    downloading it from headlamp_chart_repository.

    Default is true, which makes the module self-contained: it installs with no
    egress from the machine running Terraform, and the chart that was reviewed is
    the chart that gets installed. Set to false to pull from the repository,
    which is convenient when tracking upstream releases closely.

    Note this only removes the *build agent's* need for network access. Cluster
    nodes still pull the container image; see the README on disconnected clusters.
  EOT
  type        = bool
  default     = true
}

variable "headlamp_chart_repository" {
  description = "Helm repository that hosts the Headlamp chart. Used only when headlamp_use_local_chart is false."
  type        = string
  default     = "https://kubernetes-sigs.github.io/headlamp/"
}

variable "headlamp_chart_name" {
  description = "Chart name. Used to locate the chart in the repository, and to derive the names the chart gives its own objects."
  type        = string
  default     = "headlamp"
}

variable "headlamp_chart_version" {
  description = <<-EOT
    Exact Headlamp chart version to install. Pinning is mandatory: an unpinned
    chart makes apply non-deterministic, because a newly published chart version
    would be picked up silently on the next run.

    With headlamp_use_local_chart, this is checked against the version in the
    vendored chart's Chart.yaml and the plan fails if they differ. That keeps the
    declared version honest: swapping the vendored chart without updating this
    value is caught instead of passing silently.
  EOT
  type        = string
  default     = "0.45.0"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", var.headlamp_chart_version))
    error_message = "headlamp_chart_version must be an exact semantic version such as 0.45.0. Ranges and latest are not allowed."
  }
}

variable "headlamp_extra_values" {
  description = <<-EOT
    Additional raw YAML documents appended to the values this module generates.
    Helm merges values entries in order, so anything here overrides the
    module-generated values. This is the escape hatch for chart settings the
    module does not expose as a typed variable.
  EOT
  type        = list(string)
  default     = []
}

variable "helm_timeout_seconds" {
  description = "Time in seconds to wait for any individual Kubernetes operation during install or upgrade."
  type        = number
  default     = 600
}

variable "helm_atomic" {
  description = "Roll the release back automatically if install or upgrade fails. Implies wait."
  type        = bool
  default     = true
}

variable "helm_cleanup_on_fail" {
  description = "Delete newly created resources when an upgrade fails."
  type        = bool
  default     = true
}

variable "helm_max_history" {
  description = "Maximum number of Helm release revisions kept in the cluster. Zero means unlimited."
  type        = number
  default     = 10
}

variable "replica_count" {
  description = "Number of Headlamp pod replicas."
  type        = number
  default     = 2

  validation {
    condition     = var.replica_count >= 1
    error_message = "replica_count must be at least 1."
  }
}

variable "image_pull_policy" {
  description = "Image pull policy for the Headlamp container."
  type        = string
  default     = "IfNotPresent"

  validation {
    condition     = contains(["Always", "IfNotPresent", "Never"], var.image_pull_policy)
    error_message = "image_pull_policy must be one of Always, IfNotPresent or Never."
  }
}

variable "base_url" {
  description = "Sub-path Headlamp is served under, for example /headlamp. Empty means the root path."
  type        = string
  default     = ""
}

variable "session_ttl_seconds" {
  description = "Headlamp session token lifetime in seconds."
  type        = number
  default     = 28800
}

################################################################################
# Headlamp service account permissions
#
# This is the most important security switch in the module. See README.
################################################################################

variable "headlamp_cluster_role_binding_enabled" {
  description = <<-EOT
    Create the chart's ClusterRoleBinding for Headlamp's own ServiceAccount.

    The upstream chart defaults this to true and binds the ServiceAccount to
    cluster-admin. With OIDC enabled that binding is both unnecessary and
    dangerous: Headlamp forwards the signed-in user's token to the Kubernetes
    API, so per-user RBAC is what should decide access. Leaving the chart
    default in place gives the Headlamp pod standing cluster-admin.

    This module defaults to false. Set it to true only with a documented reason,
    and point headlamp_cluster_role_binding_role_name at a least-privilege role.
  EOT
  type        = bool
  default     = false
}

variable "headlamp_cluster_role_binding_role_name" {
  description = "ClusterRole bound to Headlamp's ServiceAccount when headlamp_cluster_role_binding_enabled is true."
  type        = string
  default     = "view"

  validation {
    condition     = var.headlamp_cluster_role_binding_role_name != "cluster-admin"
    error_message = "Refusing to bind Headlamp's ServiceAccount to cluster-admin. Choose a least-privilege ClusterRole."
  }
}

variable "service_account_name" {
  description = "Name of the ServiceAccount used by Headlamp. Null lets the chart generate one from the release name."
  type        = string
  default     = null
}

variable "service_account_annotations" {
  description = "Annotations applied to Headlamp's ServiceAccount, for example an Entra Workload Identity client ID."
  type        = map(string)
  default     = {}
}

################################################################################
# OIDC and Microsoft Entra ID
#
# The App Registration itself is NOT managed here. See README.
################################################################################

variable "oidc_enabled" {
  description = "Configure Headlamp for OIDC sign-in. When false, Headlamp falls back to manual token entry."
  type        = bool
  default     = true
}

variable "oidc_client_id" {
  description = "Application (client) ID of the externally managed Entra App Registration."
  type        = string
  default     = null

  validation {
    condition     = !var.oidc_enabled || var.oidc_existing_secret_name != null || var.oidc_client_id != null
    error_message = "oidc_client_id is required when oidc_enabled is true and oidc_existing_secret_name is not set."
  }
}

variable "oidc_client_secret" {
  description = <<-EOT
    Client secret of the externally managed Entra App Registration.

    When this is set the module creates a Kubernetes Secret from it, and the
    value is stored in Terraform state in plain text. Use
    oidc_existing_secret_name in production instead.
  EOT
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = !var.oidc_enabled || var.oidc_existing_secret_name != null || var.oidc_client_secret != null
    error_message = "oidc_client_secret is required when oidc_enabled is true and oidc_existing_secret_name is not set."
  }
}

variable "oidc_issuer_url" {
  description = "OIDC issuer used for the sign-in flow. For Entra ID this is https://login.microsoftonline.com/TENANT_ID/v2.0."
  type        = string
  default     = null

  validation {
    condition     = var.oidc_issuer_url == null || can(regex("^https://", coalesce(var.oidc_issuer_url, "https://placeholder")))
    error_message = "oidc_issuer_url must be an https URL."
  }

  validation {
    condition     = !var.oidc_enabled || var.oidc_existing_secret_name != null || var.oidc_issuer_url != null
    error_message = "oidc_issuer_url is required when oidc_enabled is true and oidc_existing_secret_name is not set."
  }
}

variable "oidc_scopes" {
  description = <<-EOT
    Scopes requested during sign-in.

    On AKS with Entra integration the access token must be issued for the AKS
    AAD Server application, so the list must include that application's
    user.read scope. See the README section on token audience for why.
  EOT
  type        = list(string)
  default = [
    "6dae42f8-4368-4678-94ff-3960e28e3630/user.read",
    "openid",
    "email",
    "profile",
  ]

  validation {
    condition     = length(var.oidc_scopes) > 0
    error_message = "oidc_scopes must contain at least one scope."
  }
}

variable "oidc_use_access_token" {
  description = <<-EOT
    Send the OAuth access token to the Kubernetes API instead of the ID token.

    Required on AKS. The ID token's audience is the Headlamp App Registration,
    which the AKS API server does not accept. The access token requested with
    the AKS AAD Server scope carries the audience the API server expects.
  EOT
  type        = bool
  default     = true
}

variable "oidc_use_pkce" {
  description = "Use PKCE in the authorization code flow."
  type        = bool
  default     = false
}

variable "oidc_validator_client_id" {
  description = <<-EOT
    Client ID used when validating the token audience. On AKS this is the AKS
    AAD Server application ID, because the access token is issued for that
    application rather than for the Headlamp App Registration.
  EOT
  type        = string
  default     = "6dae42f8-4368-4678-94ff-3960e28e3630"
}

variable "oidc_validator_issuer_url" {
  description = <<-EOT
    Issuer used when validating the token. Entra ID issues v1 access tokens for
    the AKS AAD Server application, so this is https://sts.windows.net/TENANT_ID/
    even though oidc_issuer_url points at the v2.0 endpoint.
  EOT
  type        = string
  default     = null
}

variable "oidc_redirect_url" {
  description = <<-EOT
    Full callback URL registered as a redirect URI on the App Registration.
    Must end with /oidc-callback.

    When null and ingress is enabled, the module derives it from the ingress
    host. There is no localhost default, because a localhost callback would
    silently break a production deployment.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.oidc_redirect_url == null || can(regex("^https?://[^/]+.*/oidc-callback$", coalesce(var.oidc_redirect_url, "https://x/oidc-callback")))
    error_message = "oidc_redirect_url must be an http or https URL ending in /oidc-callback."
  }
}

variable "oidc_existing_secret_name" {
  description = <<-EOT
    Name of a Kubernetes Secret that already exists in the Headlamp namespace and
    holds the OIDC credentials. This is the recommended production path: the
    secret never passes through Terraform state or Helm release data.

    The Secret must contain these keys, which the chart loads with envFrom:
    OIDC_CLIENT_ID, OIDC_CLIENT_SECRET and OIDC_ISSUER_URL.

    Typically populated by the Secrets Store CSI driver with Azure Key Vault, or
    by the External Secrets Operator.
  EOT
  type        = string
  default     = null
}

################################################################################
# Service
################################################################################

variable "service_type" {
  description = "Kubernetes Service type. Defaults to ClusterIP so Headlamp is not exposed publicly by default."
  type        = string
  default     = "ClusterIP"

  validation {
    condition     = contains(["ClusterIP", "NodePort", "LoadBalancer"], var.service_type)
    error_message = "service_type must be one of ClusterIP, NodePort or LoadBalancer."
  }
}

variable "service_port" {
  description = "Port exposed by the Headlamp Service."
  type        = number
  default     = 80
}

variable "service_annotations" {
  description = "Annotations on the Headlamp Service, for example an internal load balancer annotation."
  type        = map(string)
  default     = {}
}

################################################################################
# Ingress
################################################################################

variable "ingress_enabled" {
  description = "Create an Ingress for Headlamp."
  type        = bool
  default     = false
}

variable "ingress_class_name" {
  description = <<-EOT
    ingressClassName on the Ingress object. The module makes no assumption about
    which controller you run. Supply the class your cluster actually has, for
    example nginx, webapprouting.kubernetes.azure.com, or azure-application-gateway.
  EOT
  type        = string
  default     = null
}

variable "ingress_host" {
  description = "Hostname for the Headlamp Ingress. Required when ingress_enabled is true."
  type        = string
  default     = null

  validation {
    condition     = !var.ingress_enabled || var.ingress_host != null
    error_message = "ingress_host is required when ingress_enabled is true."
  }
}

variable "ingress_paths" {
  description = "Paths published on the Ingress host. The type field maps to the Ingress pathType field."
  type = list(object({
    path = string
    type = optional(string, "Prefix")
  }))
  default = [{ path = "/", type = "Prefix" }]

  validation {
    condition     = alltrue([for p in var.ingress_paths : contains(["Exact", "Prefix", "ImplementationSpecific"], p.type)])
    error_message = "Each ingress path type must be Exact, Prefix or ImplementationSpecific."
  }
}

variable "ingress_tls_enabled" {
  description = "Add a TLS block to the Ingress. Strongly recommended: the OIDC flow moves bearer tokens through the browser."
  type        = bool
  default     = true
}

variable "ingress_tls_secret_name" {
  description = "Name of the Kubernetes TLS Secret referenced by the Ingress. Required when ingress_tls_enabled is true."
  type        = string
  default     = null

  validation {
    condition     = !(var.ingress_enabled && var.ingress_tls_enabled) || var.ingress_tls_secret_name != null
    error_message = "ingress_tls_secret_name is required when ingress_enabled and ingress_tls_enabled are both true."
  }
}

variable "ingress_annotations" {
  description = "Annotations on the Ingress object. Controller-specific settings such as TLS redirect belong here."
  type        = map(string)
  default     = {}
}

variable "ingress_labels" {
  description = "Extra labels on the Ingress object."
  type        = map(string)
  default     = {}
}

################################################################################
# Workload hardening
################################################################################

variable "resources" {
  description = "CPU and memory requests and limits for the Headlamp container. Treat the defaults as a starting point and tune from real usage."
  type = object({
    requests = optional(object({
      cpu    = optional(string, "100m")
      memory = optional(string, "128Mi")
    }), {})
    limits = optional(object({
      cpu    = optional(string, "500m")
      memory = optional(string, "256Mi")
    }), {})
  })
  default = {}
}

variable "pod_security_context" {
  description = "Pod-level security context for the Headlamp pod."
  type = object({
    runAsNonRoot   = optional(bool, true)
    fsGroup        = optional(number, 101)
    seccompProfile = optional(object({ type = optional(string, "RuntimeDefault") }), {})
  })
  default = {}
}

variable "container_security_context" {
  description = <<-EOT
    Container-level security context. The chart replaces its own defaults
    wholesale when this value is set, so every field is listed explicitly here.

    readOnlyRootFilesystem is on by default. The chart mounts an emptyDir at
    /tmp automatically when it sees that setting, so no extra volume is needed.
    UID 100 and GID 101 are the identities the upstream Headlamp image ships with.
  EOT
  type = object({
    runAsNonRoot             = optional(bool, true)
    runAsUser                = optional(number, 100)
    runAsGroup               = optional(number, 101)
    allowPrivilegeEscalation = optional(bool, false)
    privileged               = optional(bool, false)
    readOnlyRootFilesystem   = optional(bool, true)
    capabilities = optional(object({
      drop = optional(list(string), ["ALL"])
    }), {})
    seccompProfile = optional(object({ type = optional(string, "RuntimeDefault") }), {})
  })
  default = {}
}

variable "probes" {
  description = "Liveness and readiness probe tuning. Set scheme to HTTPS only if you terminate TLS inside the Headlamp container."
  type = object({
    scheme = optional(string, "HTTP")
    liveness = optional(object({
      initialDelaySeconds = optional(number, 10)
      periodSeconds       = optional(number, 10)
      timeoutSeconds      = optional(number, 3)
      failureThreshold    = optional(number, 3)
    }), {})
    readiness = optional(object({
      initialDelaySeconds = optional(number, 5)
      periodSeconds       = optional(number, 10)
      timeoutSeconds      = optional(number, 3)
      successThreshold    = optional(number, 1)
      failureThreshold    = optional(number, 3)
    }), {})
  })
  default = {}

  validation {
    condition     = contains(["HTTP", "HTTPS"], var.probes.scheme)
    error_message = "probes.scheme must be HTTP or HTTPS."
  }
}

variable "pod_annotations" {
  description = "Annotations added to the Headlamp pod."
  type        = map(string)
  default     = {}
}

variable "pod_labels" {
  description = "Labels added to the Headlamp pod."
  type        = map(string)
  default     = {}
}

variable "node_selector" {
  description = "Node selector for the Headlamp pod."
  type        = map(string)
  default     = {}
}

variable "tolerations" {
  description = "Tolerations for the Headlamp pod, passed through to the chart unchanged."
  type = list(object({
    key               = optional(string)
    operator          = optional(string)
    value             = optional(string)
    effect            = optional(string)
    tolerationSeconds = optional(number)
  }))
  default = []
}

variable "pod_disruption_budget_enabled" {
  description = "Create a PodDisruptionBudget for Headlamp."
  type        = bool
  default     = true
}

variable "pod_disruption_budget_min_available" {
  description = "The minAvailable setting for the PodDisruptionBudget."
  type        = number
  default     = 1
}

################################################################################
# RBAC
################################################################################

variable "rbac_enabled" {
  description = "Create the RBAC objects that map Entra groups to Kubernetes permissions. Set to false to deploy Headlamp only."
  type        = bool
  default     = true
}

variable "rbac_role_definitions" {
  description = <<-EOT
    Permission sets rendered as module-managed ClusterRoles, keyed by logical
    role name. A ClusterRole is created for each key actually referenced by a
    group, and is bound either cluster-wide with a ClusterRoleBinding or per
    namespace with a RoleBinding. Rules naming cluster-scoped resources such as
    nodes simply have no effect when the role is bound with a RoleBinding.

    Override a key to change what read, write or admin means in your
    organisation. Note that the default write role includes secrets: anyone
    holding it can read every secret value in the bound namespaces.
  EOT
  type = map(object({
    rules = list(object({
      api_groups        = list(string)
      resources         = list(string)
      verbs             = list(string)
      resource_names    = optional(list(string), [])
      non_resource_urls = optional(list(string), [])
    }))
  }))

  default = {
    read = {
      rules = [
        {
          api_groups = [""]
          resources  = ["pods", "pods/log", "pods/status", "services", "endpoints", "configmaps", "persistentvolumeclaims", "replicationcontrollers", "limitranges", "resourcequotas", "events"]
          verbs      = ["get", "list", "watch"]
        },
        {
          api_groups = ["apps"]
          resources  = ["deployments", "replicasets", "statefulsets", "daemonsets", "controllerrevisions"]
          verbs      = ["get", "list", "watch"]
        },
        {
          api_groups = ["batch"]
          resources  = ["jobs", "cronjobs"]
          verbs      = ["get", "list", "watch"]
        },
        {
          api_groups = ["networking.k8s.io"]
          resources  = ["ingresses", "networkpolicies"]
          verbs      = ["get", "list", "watch"]
        },
        {
          api_groups = ["autoscaling"]
          resources  = ["horizontalpodautoscalers"]
          verbs      = ["get", "list", "watch"]
        },
        {
          api_groups = ["policy"]
          resources  = ["poddisruptionbudgets"]
          verbs      = ["get", "list", "watch"]
        },
        {
          api_groups = ["discovery.k8s.io"]
          resources  = ["endpointslices"]
          verbs      = ["get", "list", "watch"]
        },
        {
          api_groups = ["events.k8s.io"]
          resources  = ["events"]
          verbs      = ["get", "list", "watch"]
        },
        {
          api_groups = ["metrics.k8s.io"]
          resources  = ["pods", "nodes"]
          verbs      = ["get", "list", "watch"]
        },
        # Cluster-scoped read. Effective only through a ClusterRoleBinding.
        {
          api_groups = [""]
          resources  = ["nodes", "namespaces", "persistentvolumes"]
          verbs      = ["get", "list", "watch"]
        },
        {
          api_groups = ["storage.k8s.io"]
          resources  = ["storageclasses", "csidrivers", "csinodes", "volumeattachments"]
          verbs      = ["get", "list", "watch"]
        },
        {
          api_groups = ["apiextensions.k8s.io"]
          resources  = ["customresourcedefinitions"]
          verbs      = ["get", "list", "watch"]
        },
      ]
    }

    write = {
      rules = [
        {
          api_groups = [""]
          resources  = ["pods", "services", "configmaps", "secrets", "persistentvolumeclaims"]
          verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
        },
        {
          api_groups = [""]
          resources  = ["pods/log", "pods/status", "endpoints", "events", "limitranges", "resourcequotas"]
          verbs      = ["get", "list", "watch"]
        },
        {
          api_groups = ["apps"]
          resources  = ["deployments", "replicasets", "statefulsets", "daemonsets"]
          verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
        },
        {
          api_groups = ["apps"]
          resources  = ["deployments/scale", "statefulsets/scale", "replicasets/scale", "controllerrevisions"]
          verbs      = ["get", "list", "watch", "update", "patch"]
        },
        {
          api_groups = ["batch"]
          resources  = ["jobs", "cronjobs"]
          verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
        },
        {
          api_groups = ["networking.k8s.io"]
          resources  = ["ingresses", "networkpolicies"]
          verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
        },
        {
          api_groups = ["autoscaling"]
          resources  = ["horizontalpodautoscalers"]
          verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
        },
        {
          api_groups = ["policy"]
          resources  = ["poddisruptionbudgets"]
          verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
        },
        {
          api_groups = ["discovery.k8s.io"]
          resources  = ["endpointslices"]
          verbs      = ["get", "list", "watch"]
        },
        {
          api_groups = ["events.k8s.io"]
          resources  = ["events"]
          verbs      = ["get", "list", "watch"]
        },
        {
          api_groups = ["metrics.k8s.io"]
          resources  = ["pods"]
          verbs      = ["get", "list", "watch"]
        },
      ]
    }

    admin = {
      rules = [
        {
          api_groups = [""]
          resources  = ["pods", "pods/log", "pods/status", "pods/exec", "pods/portforward", "pods/attach", "services", "configmaps", "secrets", "persistentvolumeclaims", "serviceaccounts", "endpoints", "events", "namespaces", "replicationcontrollers", "limitranges", "resourcequotas"]
          verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
        },
        {
          api_groups = [""]
          resources  = ["nodes", "persistentvolumes"]
          verbs      = ["get", "list", "watch", "update", "patch"]
        },
        {
          api_groups = ["apps"]
          resources  = ["deployments", "replicasets", "statefulsets", "daemonsets", "controllerrevisions", "deployments/scale", "statefulsets/scale", "replicasets/scale"]
          verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
        },
        {
          api_groups = ["batch"]
          resources  = ["jobs", "cronjobs"]
          verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
        },
        {
          api_groups = ["networking.k8s.io"]
          resources  = ["ingresses", "ingressclasses", "networkpolicies"]
          verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
        },
        {
          api_groups = ["autoscaling"]
          resources  = ["horizontalpodautoscalers"]
          verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
        },
        {
          api_groups = ["policy"]
          resources  = ["poddisruptionbudgets"]
          verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
        },
        {
          api_groups = ["rbac.authorization.k8s.io"]
          resources  = ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
          verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
        },
        {
          api_groups = ["storage.k8s.io"]
          resources  = ["storageclasses", "csidrivers", "csinodes", "volumeattachments"]
          verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
        },
        {
          api_groups = ["apiextensions.k8s.io"]
          resources  = ["customresourcedefinitions"]
          verbs      = ["get", "list", "watch"]
        },
        {
          api_groups = ["coordination.k8s.io"]
          resources  = ["leases"]
          verbs      = ["get", "list", "watch"]
        },
        {
          api_groups = ["discovery.k8s.io"]
          resources  = ["endpointslices"]
          verbs      = ["get", "list", "watch"]
        },
        {
          api_groups = ["events.k8s.io"]
          resources  = ["events"]
          verbs      = ["get", "list", "watch"]
        },
        {
          api_groups = ["metrics.k8s.io"]
          resources  = ["pods", "nodes"]
          verbs      = ["get", "list", "watch"]
        },
        {
          api_groups = ["node.k8s.io"]
          resources  = ["runtimeclasses"]
          verbs      = ["get", "list", "watch"]
        },
        {
          api_groups = ["scheduling.k8s.io"]
          resources  = ["priorityclasses"]
          verbs      = ["get", "list", "watch"]
        },
      ]
    }
  }

  validation {
    condition     = alltrue([for k, v in var.rbac_role_definitions : can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", k)) && length(k) <= 30])
    error_message = "Each role key must be a lowercase RFC 1123 label of at most 30 characters, because it becomes part of a Kubernetes object name."
  }

  validation {
    condition = alltrue(flatten([
      for k, v in var.rbac_role_definitions : [
        for r in v.rules : length(r.verbs) > 0 && (length(r.resources) > 0 || length(r.non_resource_urls) > 0)
      ]
    ]))
    error_message = "Every rule must declare at least one verb and at least one resource or non-resource URL."
  }
}

variable "custom_roles" {
  description = <<-EOT
    Additional ClusterRoles created by the module and merged into
    rbac_role_definitions. Use this for application-specific permission sets
    without restating the built-in read, write and admin definitions.

    Rules are a list rather than a single api_groups, resources and verbs
    triple, because most real roles need more than one rule. Reading pods and
    reading pod logs, for instance, are two different rules.
  EOT
  type = map(object({
    rules = list(object({
      api_groups        = list(string)
      resources         = list(string)
      verbs             = list(string)
      resource_names    = optional(list(string), [])
      non_resource_urls = optional(list(string), [])
    }))
  }))
  default = {}

  validation {
    condition     = alltrue([for k, v in var.custom_roles : can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", k)) && length(k) <= 30])
    error_message = "Each custom role key must be a lowercase RFC 1123 label of at most 30 characters."
  }
}

variable "namespace_roles" {
  description = <<-EOT
    Namespace-scoped Roles created by the module. Use these when a permission set
    only ever makes sense inside one namespace and should not exist as a
    cluster-wide object. Reference a key from a group's namespace_role_name.
  EOT
  type = map(object({
    namespace = string
    rules = list(object({
      api_groups     = list(string)
      resources      = list(string)
      verbs          = list(string)
      resource_names = optional(list(string), [])
    }))
  }))
  default = {}

  validation {
    condition     = alltrue([for k, v in var.namespace_roles : can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", v.namespace))])
    error_message = "Each namespace_roles entry must target a valid RFC 1123 namespace name."
  }

  validation {
    condition     = alltrue([for k, v in var.namespace_roles : can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", k)) && length(k) <= 40])
    error_message = "Each namespace_roles key must be a lowercase RFC 1123 label of at most 40 characters."
  }
}

variable "rbac_groups" {
  description = <<-EOT
    Microsoft Entra groups mapped to Kubernetes permissions, keyed by a short
    logical name that becomes part of the binding object names.

    object_id is the Entra group object ID. AKS puts group object IDs in the
    token's groups claim, so the object ID, not the display name, is the identity
    Kubernetes authorises against.

    scope "cluster" creates a ClusterRoleBinding. scope "namespace" creates one
    RoleBinding per namespace listed, and namespaces is then required.

    Exactly one permission source must be set per group. Use role for a key in
    rbac_role_definitions or custom_roles, which the module creates and binds.
    Use cluster_role_name to bind an existing ClusterRole such as view or edit.
    Use namespace_role_name for a key in namespace_roles, with namespace scope.
  EOT
  type = map(object({
    object_id           = string
    scope               = string
    role                = optional(string)
    cluster_role_name   = optional(string)
    namespace_role_name = optional(string)
    namespaces          = optional(list(string), [])
  }))
  default = {}

  validation {
    condition     = alltrue([for k, g in var.rbac_groups : can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", k)) && length(k) <= 40])
    error_message = "Each rbac_groups key must be a lowercase RFC 1123 label of at most 40 characters."
  }

  validation {
    condition     = alltrue([for k, g in var.rbac_groups : can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", g.object_id))])
    error_message = "Each object_id must be a GUID. Entra group display names are not valid Kubernetes RBAC subjects on AKS."
  }

  validation {
    condition     = alltrue([for k, g in var.rbac_groups : contains(["cluster", "namespace"], g.scope)])
    error_message = "Each group scope must be cluster or namespace."
  }

  validation {
    condition     = alltrue([for k, g in var.rbac_groups : g.scope != "namespace" || length(g.namespaces) > 0])
    error_message = "A group with namespace scope must list at least one namespace."
  }

  validation {
    condition     = alltrue([for k, g in var.rbac_groups : g.scope != "cluster" || length(g.namespaces) == 0])
    error_message = "A group with cluster scope must not list namespaces. Cluster scope already covers every namespace."
  }

  validation {
    condition = alltrue([
      for k, g in var.rbac_groups :
      length(compact([g.role, g.cluster_role_name, g.namespace_role_name])) == 1
    ])
    error_message = "Each group must set exactly one of role, cluster_role_name or namespace_role_name."
  }

  validation {
    condition     = alltrue([for k, g in var.rbac_groups : g.namespace_role_name == null || g.scope == "namespace"])
    error_message = "namespace_role_name can only be used with namespace scope."
  }

  validation {
    condition = alltrue(flatten([
      for k, g in var.rbac_groups : [
        for ns in g.namespaces : can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", ns)) && length(ns) <= 63
      ]
    ]))
    error_message = "Every namespace listed in rbac_groups must be a valid RFC 1123 DNS label."
  }

  validation {
    condition = alltrue([
      for k, g in var.rbac_groups :
      g.role == null ? true : contains(keys(merge(var.rbac_role_definitions, var.custom_roles)), coalesce(g.role, "read"))
    ])
    error_message = "Each group role must be a key defined in rbac_role_definitions or custom_roles."
  }

  validation {
    condition = alltrue([
      for k, g in var.rbac_groups :
      g.namespace_role_name == null ? true : contains(keys(var.namespace_roles), coalesce(g.namespace_role_name, "placeholder"))
    ])
    error_message = "Each group namespace_role_name must be a key defined in namespace_roles."
  }
}
