provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

provider "azuread" {}

# The Kubernetes and Helm providers authenticate to the (private) API server
# using the cluster CA + an exec credential. Because local accounts are disabled
# and AAD RBAC is enforced, kubelogin brokers an Entra ID token. Ensure the
# runner (CI agent / bastion) has network line-of-sight to the private endpoint.
provider "kubernetes" {
  host                   = module.aks_cluster.host
  cluster_ca_certificate = base64decode(module.aks_cluster.cluster_ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "kubelogin"
    args = [
      "get-token",
      "--login", "azurecli",
      "--server-id", "6dae42f8-4368-4678-94ff-3960e28e3630",
    ]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.aks_cluster.host
    cluster_ca_certificate = base64decode(module.aks_cluster.cluster_ca_certificate)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "kubelogin"
      args = [
        "get-token",
        "--login", "azurecli",
        "--server-id", "6dae42f8-4368-4678-94ff-3960e28e3630",
      ]
    }
  }
}
