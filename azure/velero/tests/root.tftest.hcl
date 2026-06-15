###############################################################################
# Root configuration tests (terraform test).
#
# Exercises the product end to end against a mocked Azure + mocked cluster. The
# existing-cluster data source is overridden with known values so the OIDC
# issuer, node resource group and kube_config are deterministic offline.
###############################################################################

mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id       = "00000000-0000-0000-0000-000000000000"
      object_id       = "00000000-0000-0000-0000-000000000001"
      client_id       = "00000000-0000-0000-0000-000000000002"
      subscription_id = "00000000-0000-0000-0000-000000000003"
    }
  }
}
mock_provider "helm" {}
mock_provider "kubernetes" {}

# Deterministic stand-in for the existing AKS cluster the product reads.
override_data {
  target = data.azurerm_kubernetes_cluster.this
  values = {
    oidc_issuer_url     = "https://oidc.prod-aks.southeastasia.azmk8s.io/abc123/"
    node_resource_group = "MC_rg-aks-prod_aks-prod_southeastasia"
    kube_config = [{
      host                   = "https://aks-prod-1234.hcp.southeastasia.azmk8s.io:443"
      cluster_ca_certificate = "dGVzdC1jYQ=="
    }]
  }
}

variables {
  aks_cluster_name        = "aks-prod"
  aks_resource_group_name = "rg-aks-prod"
  storage_account_name    = "stveleroprod01"
}

run "plan_is_clean" {
  command = plan
}

run "backup_storage_wired_through" {
  command = plan

  assert {
    condition     = output.storage_account_name == var.storage_account_name
    error_message = "Backup storage account name should flow through to the output."
  }

  assert {
    condition     = output.backup_container_name == "velero"
    error_message = "Default backup container should be 'velero'."
  }
}

run "snapshot_scope_targets_node_resource_group" {
  command = plan

  assert {
    condition     = output.node_resource_group_id == "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/MC_rg-aks-prod_aks-prod_southeastasia"
    error_message = "Snapshot scope must resolve to the cluster's node resource group."
  }
}

run "service_account_federation_subject_is_correct" {
  command = plan

  assert {
    condition     = output.federated_credential_subject == "system:serviceaccount:velero:velero"
    error_message = "Federated credential subject must match the installed namespace/service account."
  }
}

run "plan_clean_with_extra_snapshot_scopes" {
  command = plan

  variables {
    extra_snapshot_scope_ids = [
      "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-data-disks",
    ]
  }

  # A clean plan with the extra scope is the assertion; also confirm the node RG
  # scope is still derived correctly alongside it.
  assert {
    condition     = output.node_resource_group_id == "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/MC_rg-aks-prod_aks-prod_southeastasia"
    error_message = "Node resource group scope must remain correct when extra scopes are supplied."
  }
}
