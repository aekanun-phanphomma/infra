################################################################################
# Example: Headlamp on an existing AKS cluster
#
# This root configuration owns the provider credentials. The module never
# configures a provider, which is what lets the same module serve several
# clusters from different root configurations.
#
# The kubeconfig is expected to already exist, produced by:
#
#   az aks get-credentials --resource-group <rg> --name <cluster>
#   kubelogin convert-kubeconfig -l azurecli
#
# The second command matters on an Entra-integrated cluster: it rewrites the
# kubeconfig to fetch Entra tokens through the Azure CLI instead of the
# deprecated in-tree provider.
################################################################################

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.2"
    }
  }
}

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kubeconfig_context
}

provider "helm" {
  kubernetes = {
    config_path    = var.kubeconfig_path
    config_context = var.kubeconfig_context
  }
}

################################################################################
# Headlamp
################################################################################

module "headlamp" {
  source = "../modules/headlamp"

  # ---------------------------------------------------------------- placement
  headlamp_namespace = "headlamp"
  create_namespace   = true

  labels = {
    "app.kubernetes.io/part-of" = "platform"
  }

  # -------------------------------------------------------------------- chart
  headlamp_chart_version = "0.45.0"
  replica_count          = 2

  # ---------------------------------------------------------------------- OIDC
  # The App Registration behind these values is created and owned outside
  # Terraform. See the README for exactly what has to exist first.
  oidc_enabled    = true
  oidc_client_id  = var.oidc_client_id
  oidc_issuer_url = "https://login.microsoftonline.com/${var.tenant_id}/v2.0"

  # Entra issues the access token for the AKS AAD Server application, from the
  # v1 endpoint, so validation uses a different client ID and issuer than
  # sign-in does. Both defaults in the module already match AKS; they are
  # spelled out here because this is the part people get wrong.
  oidc_use_access_token     = true
  oidc_validator_client_id  = "6dae42f8-4368-4678-94ff-3960e28e3630"
  oidc_validator_issuer_url = "https://sts.windows.net/${var.tenant_id}/"

  oidc_scopes = [
    "6dae42f8-4368-4678-94ff-3960e28e3630/user.read",
    "openid",
    "email",
    "profile",
  ]

  # Production path: a Secret that already exists in the namespace, populated by
  # the Secrets Store CSI driver or the External Secrets Operator. Leave
  # oidc_existing_secret_name null and set oidc_client_secret instead to let
  # Terraform create it, accepting that the value then lives in state.
  oidc_existing_secret_name = var.oidc_existing_secret_name
  oidc_client_secret        = var.oidc_client_secret

  # ------------------------------------------------------------------- ingress
  # No controller is assumed. Supply whichever ingress class the cluster has.
  ingress_enabled         = true
  ingress_class_name      = var.ingress_class_name
  ingress_host            = var.headlamp_hostname
  ingress_tls_enabled     = true
  ingress_tls_secret_name = var.ingress_tls_secret_name
  ingress_annotations     = var.ingress_annotations

  # The callback URL is derived from the ingress host as
  # https://<host>/oidc-callback, and is exported as an output so it can be
  # checked against the redirect URI registered on the App Registration.

  # ---------------------------------------------------------------------- RBAC
  # An extra permission set on top of the built-in read, write and admin roles.
  custom_roles = {
    application-operator = {
      rules = [
        {
          api_groups = ["apps"]
          resources  = ["deployments", "deployments/scale", "statefulsets", "statefulsets/scale"]
          verbs      = ["get", "list", "watch", "update", "patch"]
        },
        {
          api_groups = [""]
          resources  = ["pods", "pods/log"]
          verbs      = ["get", "list", "watch"]
        },
      ]
    }
  }

  rbac_groups = {
    # Cluster administration. Bound to the module's explicit admin ClusterRole,
    # not to cluster-admin.
    aks-admin = {
      object_id = var.group_object_ids.aks_admin
      scope     = "cluster"
      role      = "admin"
    }

    # Read-only across every namespace, including namespaces created later.
    aks-read = {
      object_id = var.group_object_ids.aks_read
      scope     = "cluster"
      role      = "read"
    }

    # Write access confined to two namespaces. One RoleBinding is created per
    # namespace, so nothing leaks into namespace team-c.
    aks-write = {
      object_id  = var.group_object_ids.aks_write
      scope      = "namespace"
      role       = "write"
      namespaces = ["team-a", "team-b"]
    }

    app-a-read = {
      object_id  = var.group_object_ids.app_a_read
      scope      = "namespace"
      role       = "read"
      namespaces = ["application-a"]
    }

    app-a-write = {
      object_id  = var.group_object_ids.app_a_write
      scope      = "namespace"
      role       = "write"
      namespaces = ["application-a"]
    }

    # Demonstrates the custom role above, and that an arbitrary number of groups
    # is supported rather than a fixed three.
    app-a-operator = {
      object_id  = var.group_object_ids.app_a_operator
      scope      = "namespace"
      role       = "application-operator"
      namespaces = ["application-a"]
    }
  }
}
