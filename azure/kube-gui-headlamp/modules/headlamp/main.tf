################################################################################
# Namespace
#
# Created by the Kubernetes provider rather than by Helm's create_namespace, so
# that the namespace is an explicitly managed object with its own labels and is
# not destroyed as a side effect of removing the release.
################################################################################

resource "kubernetes_namespace_v1" "this" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name        = var.headlamp_namespace
    labels      = local.namespace_labels
    annotations = var.annotations
  }
}

locals {
  # Referencing the created namespace here, rather than the variable, is what
  # orders the Helm release after the namespace. No depends_on is needed.
  namespace = var.create_namespace ? kubernetes_namespace_v1.this[0].metadata[0].name : var.headlamp_namespace
}

################################################################################
# OIDC secret
#
# Only created when the caller passes the client secret directly. In that mode
# the secret value is written to Terraform state in plain text, which is why
# oidc_existing_secret_name is the documented production path.
#
# The key names are fixed by the chart: it loads this Secret with envFrom and
# then references the variables by these exact names on the command line.
################################################################################

resource "kubernetes_secret_v1" "oidc" {
  count = local.create_oidc_secret ? 1 : 0

  metadata {
    name        = local.oidc_secret_name
    namespace   = local.namespace
    labels      = local.secret_labels
    annotations = var.annotations
  }

  type = "Opaque"

  data = {
    OIDC_CLIENT_ID     = var.oidc_client_id
    OIDC_CLIENT_SECRET = var.oidc_client_secret
    OIDC_ISSUER_URL    = var.oidc_issuer_url
  }
}

################################################################################
# Headlamp Helm release
################################################################################

resource "helm_release" "headlamp" {
  name       = var.headlamp_release_name
  repository = local.chart_repository
  chart      = local.chart_reference
  version    = local.chart_version
  namespace  = local.namespace

  # The namespace is managed above, so Helm must not create it.
  create_namespace = false

  values = local.helm_values

  # Controlled upgrade behaviour. force_update and recreate_pods stay off: both
  # replace running pods on every apply, which turns an unrelated values change
  # into an outage.
  atomic          = var.helm_atomic
  cleanup_on_fail = var.helm_cleanup_on_fail
  timeout         = var.helm_timeout_seconds
  max_history     = var.helm_max_history
  wait            = true

  # Required, not cosmetic: the pod reads the OIDC Secret through envFrom, so a
  # release that starts before the Secret exists fails its readiness wait.
  depends_on = [kubernetes_secret_v1.oidc]

  lifecycle {
    precondition {
      condition     = !var.headlamp_use_local_chart || local.local_chart_version != null
      error_message = "headlamp_use_local_chart is true but no readable chart was found at modules/headlamp/charts. Vendor the chart there, or set headlamp_use_local_chart = false to pull from the repository."
    }

    precondition {
      condition     = !var.headlamp_use_local_chart || local.local_chart_version == var.headlamp_chart_version
      error_message = "The vendored chart's version does not match headlamp_chart_version. Update the variable to match modules/headlamp/charts/Chart.yaml, or vendor the chart version you declared."
    }

    precondition {
      condition     = !var.oidc_enabled || local.oidc_redirect_url != ""
      error_message = "OIDC is enabled but no callback URL could be resolved. Set oidc_redirect_url, or enable ingress so it can be derived from ingress_host."
    }

    precondition {
      condition     = var.oidc_existing_secret_name == null || var.oidc_client_secret == null
      error_message = "oidc_existing_secret_name and oidc_client_secret are mutually exclusive. Choose either an externally managed Secret or a Terraform-managed one."
    }

    precondition {
      condition     = !var.pod_disruption_budget_enabled || var.pod_disruption_budget_min_available < var.replica_count
      error_message = "pod_disruption_budget_min_available must be lower than replica_count, otherwise the PodDisruptionBudget blocks every voluntary node drain."
    }
  }
}
