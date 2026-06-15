###############################################################################
# Module unit tests (terraform test) for ./modules/velero.
#
# Providers are mocked so the suite runs offline with no Azure credentials or
# cluster. These run blocks target the module directly, so assertions can reach
# the module's own resources. Focus: the Azure plumbing and security-relevant
# settings Velero depends on are wired as intended.
###############################################################################

mock_provider "azurerm" {}
mock_provider "helm" {}

variables {
  location             = "southeastasia"
  resource_group_name  = "rg-velero-test"
  subscription_id      = "00000000-0000-0000-0000-000000000003"
  storage_account_name = "stveleroprodtest01"
  oidc_issuer_url      = "https://oidc.prod-aks.southeastasia.azmk8s.io/abc123/"
  snapshot_scope_ids = [
    "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/MC_rg-aks_aks-prod_southeastasia",
  ]
}

run "plan_is_clean" {
  command = plan
  module {
    source = "./modules/velero"
  }
}

run "storage_account_is_keyless_and_hardened" {
  command = plan
  module {
    source = "./modules/velero"
  }

  assert {
    condition     = azurerm_storage_account.this.shared_access_key_enabled == false
    error_message = "Backup storage account must reject shared-key auth (workload identity only)."
  }

  assert {
    condition     = azurerm_storage_account.this.min_tls_version == "TLS1_2"
    error_message = "Backup storage account must require TLS 1.2."
  }

  assert {
    condition     = azurerm_storage_account.this.account_replication_type == "GRS"
    error_message = "Backup storage should be geo-redundant by default."
  }
}

run "backup_container_is_private" {
  command = plan
  module {
    source = "./modules/velero"
  }

  assert {
    condition     = azurerm_storage_container.this.container_access_type == "private"
    error_message = "Backup container must not allow anonymous access."
  }
}

run "federated_credential_binds_velero_service_account" {
  command = plan
  module {
    source = "./modules/velero"
  }

  assert {
    condition     = azurerm_federated_identity_credential.velero.subject == "system:serviceaccount:velero:velero"
    error_message = "Federated credential subject must match the Velero namespace/service-account."
  }

  assert {
    condition     = azurerm_federated_identity_credential.velero.issuer == var.oidc_issuer_url
    error_message = "Federated credential must trust the cluster OIDC issuer."
  }
}

run "blob_role_assigned_by_default" {
  command = plan
  module {
    source = "./modules/velero"
  }

  assert {
    condition     = length(azurerm_role_assignment.blob) == 1
    error_message = "Velero identity must get Storage Blob Data Contributor on the backup account."
  }

  assert {
    condition     = azurerm_role_assignment.blob[0].role_definition_name == "Storage Blob Data Contributor"
    error_message = "Blob role must be Storage Blob Data Contributor."
  }
}

run "snapshot_role_assigned_per_scope" {
  command = plan
  module {
    source = "./modules/velero"
  }

  assert {
    condition     = length(azurerm_role_assignment.snapshot) == length(var.snapshot_scope_ids)
    error_message = "One snapshot role assignment must be created per snapshot scope."
  }
}

run "velero_installed_by_default" {
  command = plan
  module {
    source = "./modules/velero"
  }

  assert {
    condition     = length(helm_release.velero) == 1
    error_message = "Velero Helm release should be installed by default."
  }
}

run "velero_install_can_be_skipped" {
  command = plan
  module {
    source = "./modules/velero"
  }

  variables {
    install_velero = false
  }

  assert {
    condition     = length(helm_release.velero) == 0
    error_message = "No Helm release should be planned when install_velero = false."
  }

  # Azure resources must still be created so a later apply can install Velero.
  assert {
    condition     = length(azurerm_role_assignment.blob) == 1
    error_message = "Azure resources must be provisioned even when the Helm install is skipped."
  }
}

run "rejects_invalid_storage_account_name" {
  command = plan
  module {
    source = "./modules/velero"
  }

  variables {
    storage_account_name = "Invalid_Name!"
  }

  expect_failures = [
    var.storage_account_name,
  ]
}

run "rejects_invalid_replication_type" {
  command = plan
  module {
    source = "./modules/velero"
  }

  variables {
    storage_replication_type = "SUPER_REDUNDANT"
  }

  expect_failures = [
    var.storage_replication_type,
  ]
}
