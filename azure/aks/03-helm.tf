###############################################################################
# 03-helm.tf — platform Helm releases bootstrapped into a freshly created
# cluster: istio-base (CRDs) -> istiod (control plane) and external-dns.
#
# These run after the node pool so workloads have somewhere to schedule. The
# runner must be able to reach the private API server (see providers.tf). On a
# brand-new environment where that path is not ready, set enable_helm_releases
# = false for the first apply, then re-enable.
###############################################################################

resource "helm_release" "istio_base" {
  count = var.enable_helm_releases ? 1 : 0

  name             = "istio-base"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "base"
  version          = var.istio_version
  namespace        = "istio-system"
  create_namespace = true
  atomic           = true
  wait             = true
  timeout          = 600

  set {
    name  = "defaultRevision"
    value = "default"
  }

  depends_on = [module.aks_nodepool_user]
}

resource "helm_release" "istiod" {
  count = var.enable_helm_releases ? 1 : 0

  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  version    = var.istio_version
  namespace  = "istio-system"
  atomic     = true
  wait       = true
  timeout    = 600

  set {
    name  = "pilot.autoscaleEnabled"
    value = "true"
  }

  depends_on = [helm_release.istio_base]
}

resource "helm_release" "external_dns" {
  count = var.enable_helm_releases ? 1 : 0

  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  version          = var.external_dns_version
  namespace        = "external-dns"
  create_namespace = true
  atomic           = true
  wait             = true
  timeout          = 600

  set {
    name  = "provider"
    value = "azure"
  }

  set {
    name  = "policy"
    value = "sync"
  }

  set {
    name  = "txtOwnerId"
    value = var.cluster_name
  }

  dynamic "set" {
    for_each = var.external_dns_azure_resource_group == null ? [] : [var.external_dns_azure_resource_group]
    content {
      name  = "extraArgs.azure-resource-group"
      value = set.value
    }
  }

  dynamic "set" {
    for_each = var.external_dns_domain_filters
    iterator = zone
    content {
      name  = "domainFilters[${zone.key}]"
      value = zone.value
    }
  }

  # external-dns authenticates via AKS workload identity; the pod's service
  # account must be federated to a managed identity with DNS Zone Contributor.
  set {
    name  = "serviceAccount.labels.azure\\.workload\\.identity/use"
    value = "true"
  }

  set {
    name  = "podLabels.azure\\.workload\\.identity/use"
    value = "true"
  }

  depends_on = [module.aks_nodepool_user]
}
