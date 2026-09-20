################################################################################
# Provider and Terraform version constraints
#
# Terraform >= 1.9.0 is required because this module uses input variable
# validation rules that reference *other* variables (for example, "oidc_client_id
# must be set when oidc_enabled is true"). Cross-variable references inside
# validation blocks were introduced in Terraform 1.9.
#
# Provider versions are pinned to the current major line. The module does NOT
# configure the providers; the root module (the caller) owns all credentials.
################################################################################

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0.0, < 4.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.30.0, < 4.0.0"
    }
  }
}
