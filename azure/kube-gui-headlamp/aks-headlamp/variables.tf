################################################################################
# Cluster connection
################################################################################

variable "kubeconfig_path" {
  description = "Path to the kubeconfig used by the Kubernetes and Helm providers."
  type        = string
  default     = "~/.kube/config"
}

variable "kubeconfig_context" {
  description = "Context inside the kubeconfig that points at the target AKS cluster."
  type        = string
}

################################################################################
# Microsoft Entra ID
#
# Every value here refers to objects created and owned outside this
# configuration. Nothing in this repository creates an App Registration, an
# Enterprise Application, a client secret or an Entra group.
################################################################################

variable "tenant_id" {
  description = "Microsoft Entra tenant (directory) ID. Used to build the issuer URLs."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.tenant_id))
    error_message = "tenant_id must be a GUID."
  }
}

variable "oidc_client_id" {
  description = "Application (client) ID of the externally managed Headlamp App Registration."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.oidc_client_id))
    error_message = "oidc_client_id must be a GUID."
  }
}

variable "oidc_existing_secret_name" {
  description = <<-EOT
    Name of a Kubernetes Secret in the Headlamp namespace that already holds
    OIDC_CLIENT_ID, OIDC_CLIENT_SECRET and OIDC_ISSUER_URL. Recommended for
    production. Leave null to have Terraform create the Secret from
    oidc_client_secret instead.
  EOT
  type        = string
  default     = null
}

variable "oidc_client_secret" {
  description = <<-EOT
    Client secret of the App Registration. Only used when
    oidc_existing_secret_name is null. Supply it through an environment variable
    such as TF_VAR_oidc_client_secret, never through a committed tfvars file.
    When set, the value is stored in Terraform state.
  EOT
  type        = string
  default     = null
  sensitive   = true
}

################################################################################
# Ingress
################################################################################

variable "headlamp_hostname" {
  description = "Public hostname for Headlamp, for example headlamp.example.com. The OIDC callback URL is derived from it."
  type        = string
}

variable "ingress_class_name" {
  description = "ingressClassName of the controller already running in the cluster."
  type        = string
}

variable "ingress_tls_secret_name" {
  description = "Kubernetes TLS Secret holding the certificate for headlamp_hostname."
  type        = string
}

variable "ingress_annotations" {
  description = "Controller-specific Ingress annotations, for example a forced HTTPS redirect."
  type        = map(string)
  default     = {}
}

################################################################################
# Entra group object IDs
#
# Object IDs, not display names: AKS puts group object IDs in the token's groups
# claim, and that is what Kubernetes RBAC matches on.
################################################################################

variable "group_object_ids" {
  description = "Object IDs of the Entra groups that receive access to the cluster through Headlamp."
  type = object({
    aks_admin      = string
    aks_read       = string
    aks_write      = string
    app_a_read     = string
    app_a_write    = string
    app_a_operator = string
  })

  validation {
    condition = alltrue([
      for id in values(var.group_object_ids) :
      can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", id))
    ])
    error_message = "Every group object ID must be a GUID."
  }
}
